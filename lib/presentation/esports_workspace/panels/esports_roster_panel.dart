import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/panels/esports_athlete_profile_panel.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsRosterPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? selectedTeamId;
  final String selectedTeamName;
  final List<Map<String, dynamic>> athletes;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> recordings;
  final List<Map<String, dynamic>> reports;
  final Set<int>? allowedAthleteIds;
  final bool canManage;
  final Future<void> Function() onRefresh;

  const EsportsRosterPanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.athletes,
    required this.teams,
    required this.matches,
    required this.recordings,
    required this.reports,
    required this.allowedAthleteIds,
    required this.canManage,
    required this.onRefresh,
  });

  @override
  State<EsportsRosterPanel> createState() => _EsportsRosterPanelState();
}

class _EsportsRosterPanelState extends State<EsportsRosterPanel> {
  final _search = TextEditingController();
  Map<String, dynamic>? _selected;
  bool _addMode = false;
  String _gameFilter = 'Все';

  @override
  void initState() {
    super.initState();
    _search.addListener(_rebuild);
    _syncSelected();
  }

  @override
  void didUpdateWidget(covariant EsportsRosterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athletes.length != widget.athletes.length ||
        oldWidget.selectedTeamId != widget.selectedTeamId) {
      _syncSelected();
    }
  }

  void _syncSelected() {
    final list = _visibleBase();
    if (_selected != null) {
      final current = _id(_selected!);
      for (final athlete in list) {
        if (_id(athlete) == current) {
          _selected = athlete;
          return;
        }
      }
    }
    _selected = list.isNotEmpty ? list.first : null;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  int _id(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['player_id'] ?? m['playerId']);
  int _teamId(Map<String, dynamic> m) => esportsInt(m['team_id'] ?? m['teamId']);

  String _tag(Map<String, dynamic> m) {
    final tag = esportsText(m['gamer_tag'] ?? m['nickname'] ?? m['game_name']);
    if (tag.isNotEmpty) return tag;
    final name = '${esportsText(m['first_name'])} ${esportsText(m['last_name'])}'.trim();
    return name.isEmpty ? 'Киберспортсмен' : name;
  }

  String _fullName(Map<String, dynamic> m) =>
      '${esportsText(m['first_name'])} ${esportsText(m['last_name'])}'.trim();

  List<Map<String, dynamic>> _visibleBase() {
    return widget.athletes.where((a) {
      if ((widget.selectedTeamId ?? 0) > 0 && _teamId(a) > 0 && _teamId(a) != widget.selectedTeamId) {
        return false;
      }
      final allowed = widget.allowedAthleteIds;
      if (allowed != null && allowed.isNotEmpty && !allowed.contains(_id(a))) return false;
      return true;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _visibleBase().where((a) {
      final game = esportsText(a['game_title'] ?? a['game']);
      if (_gameFilter != 'Все' && game != _gameFilter) return false;
      if (q.isEmpty) return true;
      final hay = [
        _tag(a),
        _fullName(a),
        game,
        esportsText(a['platform']),
        esportsText(a['rank']),
        esportsText(a['team_role']),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < 680;
        if (phone) return _phone();
        final leftWidth = c.maxWidth < 980 ? 330.0 : 420.0;
        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
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
    if (_addMode) {
      return _AthleteEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        selectedTeamId: widget.selectedTeamId,
        teams: widget.teams,
        onClose: () => setState(() => _addMode = false),
        onSaved: (_) async {
          setState(() => _addMode = false);
          await widget.onRefresh();
        },
      );
    }
    if (_selected != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Row(
            children: [
              Expanded(child: EsportsPanelHeader(title: 'Состав', subtitle: widget.selectedTeamName)),
              IconButton(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.list_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EsportsAthleteProfilePanel(athlete: _selected!, matches: widget.matches, recordings: widget.recordings, reports: widget.reports),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _topControls(compact: true),
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _listPane() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: _topControls(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              style: esportsFieldTextStyle(),
              decoration: esportsInputDecoration('Поиск по нику, имени, рангу', icon: Icons.search_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: _filterChip('Все')),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('EA Sports FC')),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('eFootball')),
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
              title: 'Состав',
              subtitle: widget.selectedTeamName.trim().isEmpty ? 'Киберспортсмены клуба' : widget.selectedTeamName,
            ),
          ),
          if (widget.canManage)
            compact
                ? IconButton(
                    onPressed: () => setState(() => _addMode = true),
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: EsportsColors.greenDark),
                  )
                : EsportsActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Добавить',
                    onTap: () => setState(() => _addMode = true),
                  ),
        ],
      );

  Widget _filterChip(String value) {
    final active = _gameFilter == value;
    return InkWell(
      onTap: () => setState(() => _gameFilter = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? EsportsColors.greenSoft : EsportsColors.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          value == 'EA Sports FC' ? 'EA FC' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.custom(
            size: 9.5,
            weight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? EsportsColors.greenDark : EsportsColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _visibleBase().isEmpty ? 'В составе пока нет киберспортсменов' : 'Ничего не найдено',
            textAlign: TextAlign.center,
            style: AppTypography.captionMedium(color: EsportsColors.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, index) {
        final athlete = list[index];
        final active = _selected != null && _id(_selected!) == _id(athlete);
        final rating = esportsInt(athlete['rating']);
        return Material(
          color: active ? EsportsColors.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () => setState(() => _selected = athlete),
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : EsportsColors.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: EsportsColors.greenDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tag(athlete), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text)),
                        const SizedBox(height: 3),
                        Text(
                          [
                            esportsText(athlete['game_title'] ?? athlete['game']),
                            esportsText(athlete['platform']),
                            if (rating > 0) '$rating',
                          ].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMedium(color: EsportsColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: EsportsColors.subtle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rightPane() {
    if (_addMode) {
      return _AthleteEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        selectedTeamId: widget.selectedTeamId,
        teams: widget.teams,
        onClose: () => setState(() => _addMode = false),
        onSaved: (athlete) async {
          setState(() {
            _addMode = false;
            _selected = athlete;
          });
          await widget.onRefresh();
        },
      );
    }
    if (_selected == null) {
      return EsportsEmptyState(
        icon: Icons.sports_esports_rounded,
        title: 'Выберите киберспортсмена',
        text: 'Справа откроется игровой профиль: ник, платформа, режим, рейтинг, ранг, матчи и AI-анализ.',
        action: widget.canManage
            ? EsportsActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Добавить киберспортсмена',
                onTap: () => setState(() => _addMode = true),
              )
            : null,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: EsportsAthleteProfilePanel(athlete: _selected!, matches: widget.matches, recordings: widget.recordings, reports: widget.reports),
    );
  }

  Widget _athleteDetails(Map<String, dynamic> athlete) {
    final name = _fullName(athlete);
    final rating = esportsInt(athlete['rating']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: EsportsColors.greenSoft,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.sports_esports_rounded, size: 29, color: EsportsColors.greenDark),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tag(athlete), style: AppTypography.custom(size: 21, weight: FontWeight.w600, color: EsportsColors.text)),
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(name, style: AppTypography.captionMedium(color: EsportsColors.muted)),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    [
                      esportsText(athlete['game_title'] ?? athlete['game']),
                      esportsText(athlete['platform']),
                      esportsText(athlete['game_mode'] ?? athlete['mode']),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: AppTypography.captionMedium(color: EsportsColors.muted),
                  ),
                ],
              ),
            ),
            EsportsStatusPill(label: 'Esports', active: true),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _metric(rating > 0 ? '$rating' : '—', 'Рейтинг')),
            const SizedBox(width: 9),
            Expanded(child: _metric(esportsText(athlete['rank']).isEmpty ? '—' : esportsText(athlete['rank']), 'Ранг')),
            const SizedBox(width: 9),
            Expanded(child: _metric(esportsText(athlete['region']).isEmpty ? '—' : esportsText(athlete['region']), 'Регион')),
          ],
        ),
        const SizedBox(height: 14),
        _infoCard('Игровой ID', esportsText(athlete['game_account_id'] ?? athlete['game_id'])),
        const SizedBox(height: 8),
        _infoCard('Роль в команде', esportsText(athlete['team_role'] ?? athlete['role'])),
        const SizedBox(height: 8),
        _infoCard('Email', esportsText(athlete['email'])),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: esportsCardDecoration(radius: 13),
          child: Text(
            'Профиль киберспортсмена не использует футбольные GPS, рост, вес и амплуа. Здесь будут игровые матчи, статистика, видео и AI-разборы.',
            style: AppTypography.custom(size: 11.5, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _metric(String value, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.subsectionTitle(color: EsportsColors.text)),
          const SizedBox(height: 3),
          Text(label, style: AppTypography.captionMedium(color: EsportsColors.muted)),
        ]),
      );

  Widget _infoCard(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(11)),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: AppTypography.captionMedium(color: EsportsColors.muted))),
          Expanded(child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.right, style: AppTypography.action(color: EsportsColors.text))),
        ]),
      );
}

class _AthleteEditor extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _AthleteEditor({
    required this.clubId,
    required this.actorUserId,
    required this.selectedTeamId,
    required this.teams,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_AthleteEditor> createState() => _AthleteEditorState();
}

class _AthleteEditorState extends State<_AthleteEditor> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _tag = TextEditingController();
  final _gameId = TextEditingController();
  final _rating = TextEditingController();
  final _rank = TextEditingController();
  final _region = TextEditingController(text: 'Europe');
  final _role = TextEditingController();
  String _game = 'EA Sports FC';
  String _platform = 'PlayStation 5';
  String _mode = 'Clubs';
  int? _teamId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _teamId = widget.selectedTeamId ?? (widget.teams.isNotEmpty ? esportsInt(widget.teams.first['id'] ?? widget.teams.first['team_id']) : null);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _tag, _gameId, _rating, _rank, _region, _role]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_tag.text.trim().isEmpty || _first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'Укажите имя, фамилию и игровой ник.');
      return;
    }
    if ((_teamId ?? 0) <= 0) {
      setState(() => _error = 'Сначала создайте или выберите киберкоманду.');
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
      'athlete_type': 'esports',
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': _email.text.trim(),
      'gamer_tag': _tag.text.trim(),
      'game_title': _game,
      'platform': _platform,
      'game_mode': _mode,
      'game_account_id': _gameId.text.trim(),
      'rating': int.tryParse(_rating.text.trim()) ?? 0,
      'rank': _rank.text.trim(),
      'region': _region.text.trim(),
      'team_role': _role.text.trim(),
    };
    final result = await EsportsApiService.createAthlete(payload);
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _saving = false;
        _error = esportsText(result['message'] ?? result['error']).isEmpty
            ? 'Не удалось добавить киберспортсмена.'
            : esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['player'] ?? result['athlete'] ?? result['data'];
    widget.onSaved(<String, dynamic>{
      ...payload,
      if (raw is Map) ...Map<String, dynamic>.from(raw),
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EsportsPanelHeader(
            title: 'Новый киберспортсмен',
            subtitle: 'Отдельный игровой профиль внутри выбранной киберкоманды',
            trailing: IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded)),
          ),
          const SizedBox(height: 16),
          _two(_field(_first, 'Имя'), _field(_last, 'Фамилия')),
          _field(_email, 'Email'),
          _field(_tag, 'Игровой ник'),
          if (widget.teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                style: esportsFieldTextStyle(),
                value: _teamId,
                decoration: esportsInputDecoration('Киберкоманда', icon: Icons.groups_2_outlined),
                items: widget.teams.map((team) {
                  final id = esportsInt(team['id'] ?? team['team_id']);
                  final name = esportsText(team['name'] ?? team['team_name']);
                  return DropdownMenuItem<int>(value: id, child: Text(name.isEmpty ? 'Команда #$id' : name, style: esportsFieldTextStyle()));
                }).where((item) => item.value != null && item.value! > 0).toList(),
                onChanged: (v) => setState(() => _teamId = v),
              ),
            ),
          _two(
            _dropdown('Игра', _game, const ['EA Sports FC', 'eFootball'], (v) => setState(() => _game = v)),
            _dropdown('Платформа', _platform, const ['PlayStation 5', 'Xbox Series', 'PC', 'Nintendo Switch', 'Cross-platform'], (v) => setState(() => _platform = v)),
          ),
          _two(
            _dropdown('Режим', _mode, const ['1×1', '2×2', 'Clubs', 'Ultimate Team', 'Командный'], (v) => setState(() => _mode = v)),
            _field(_gameId, 'Игровой ID'),
          ),
          _two(_numberField(_rating, 'Рейтинг'), _field(_rank, 'Ранг')),
          _two(_field(_region, 'Регион'), _field(_role, 'Роль / позиция в игре')),
          if (_error != null) ...[
            Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(child: EsportsActionButton(icon: Icons.close_rounded, label: 'Отмена', onTap: _saving ? null : widget.onClose, primary: false)),
              const SizedBox(width: 9),
              Expanded(flex: 2, child: EsportsActionButton(icon: Icons.person_add_alt_1_rounded, label: _saving ? 'Добавляем…' : 'Добавить', onTap: _saving ? null : _save)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, style: esportsFieldTextStyle(), decoration: esportsInputDecoration(label)),
      );

  Widget _numberField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, style: esportsFieldTextStyle(), keyboardType: TextInputType.number, decoration: esportsInputDecoration(label)),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          style: esportsFieldTextStyle(),
          value: value,
          isExpanded: true,
          decoration: esportsInputDecoration(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis, style: esportsFieldTextStyle()))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Widget _two(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 560
            ? Column(children: [a, b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );
}
