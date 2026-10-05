import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsTournamentsPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> tournaments;
  final bool canManage;
  final Future<void> Function() onRefresh;

  const EsportsTournamentsPanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.selectedTeamId,
    required this.teams,
    required this.tournaments,
    required this.canManage,
    required this.onRefresh,
  });

  @override
  State<EsportsTournamentsPanel> createState() => _EsportsTournamentsPanelState();
}

class _EsportsTournamentsPanelState extends State<EsportsTournamentsPanel> {
  Map<String, dynamic>? _selected;
  bool _createMode = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant EsportsTournamentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournaments.length != widget.tournaments.length) _sync();
  }

  void _sync() {
    if (_selected == null && widget.tournaments.isNotEmpty) {
      _selected = widget.tournaments.first;
    }
  }

  int _id(Map<String, dynamic> m) => esportsInt(m['id'] ?? m['tournament_id']);
  String _name(Map<String, dynamic> m) {
    final v = esportsText(m['name'] ?? m['title']);
    return v.isEmpty ? 'Киберспортивный турнир' : v;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 680) {
        return _createMode ? _editor() : _mobile();
      }
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: esportsCardDecoration(radius: 20),
            child: Row(children: [
              SizedBox(width: c.maxWidth < 980 ? 330 : 420, child: _listPane()),
              const SizedBox(width: 1, child: ColoredBox(color: EsportsColors.line)),
              Expanded(child: _createMode ? _editor() : _detailsPane()),
            ]),
          ),
        ),
      );
    });
  }

  Widget _mobile() => ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Row(children: [
            Expanded(child: EsportsPanelHeader(title: 'Турниры', subtitle: '${widget.tournaments.length} турниров')),
            if (widget.canManage) IconButton(onPressed: () => setState(() => _createMode = true), icon: const Icon(Icons.add_rounded, color: EsportsColors.greenDark)),
          ]),
          const SizedBox(height: 10),
          if (widget.tournaments.isEmpty)
            const EsportsEmptyState(icon: Icons.emoji_events_outlined, title: 'Турниров пока нет', text: 'Создавайте лиги, кубки и серии для EA Sports FC и eFootball.')
          else
            for (final tournament in widget.tournaments) ...[
              _tournamentCard(tournament),
              const SizedBox(height: 8),
            ],
        ],
      );

  Widget _listPane() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: EsportsPanelHeader(
            title: 'Турниры',
            subtitle: 'Лиги, кубки и серии',
            trailing: widget.canManage ? EsportsActionButton(icon: Icons.add_rounded, label: 'Создать', onTap: () => setState(() => _createMode = true)) : null,
          ),
        ),
        const Divider(height: 1, color: EsportsColors.line),
        Expanded(
          child: widget.tournaments.isEmpty
              ? Center(child: Text('Турниров пока нет', style: AppTypography.captionMedium(color: EsportsColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                  itemCount: widget.tournaments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 5),
                  itemBuilder: (_, i) {
                    final t = widget.tournaments[i];
                    final active = _selected != null && _id(_selected!) == _id(t);
                    return Material(
                      color: active ? EsportsColors.greenSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() => _selected = t),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Row(children: [
                            Container(width: 42, height: 42, decoration: BoxDecoration(color: active ? Colors.white : EsportsColors.soft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.emoji_events_outlined, color: EsportsColors.greenDark)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_name(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text)),
                              const SizedBox(height: 3),
                              Text([esportsText(t['game_title'] ?? t['game']), esportsText(t['status']), esportsText(t['start_date'])].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.captionMedium(color: EsportsColors.muted)),
                            ])),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]);

  Widget _detailsPane() {
    if (_selected == null) {
      return EsportsEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Выберите турнир',
        text: 'Здесь будут участники, матчи, сетка, Live, записи и AI-анализ турнира.',
        action: widget.canManage ? EsportsActionButton(icon: Icons.add_rounded, label: 'Создать турнир', onTap: () => setState(() => _createMode = true)) : null,
      );
    }
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 100), child: _tournamentCard(_selected!, expanded: true));
  }

  Widget _tournamentCard(Map<String, dynamic> t, {bool expanded = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: esportsCardDecoration(radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.emoji_events_outlined, color: EsportsColors.greenDark)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name(t), style: AppTypography.subsectionTitle(color: EsportsColors.text)),
            const SizedBox(height: 3),
            Text([esportsText(t['game_title'] ?? t['game']), esportsText(t['format']), esportsText(t['platform'])].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ])),
          EsportsStatusPill(label: esportsText(t['status']).isEmpty ? 'Активен' : esportsText(t['status']), active: true),
        ]),
        if (expanded) ...[
          const SizedBox(height: 14),
          _line('Период', [esportsText(t['start_date']), esportsText(t['end_date'])].where((e) => e.isNotEmpty).join(' — ')),
          _line('Участники', '${esportsInt(t['participants_count'] ?? t['teams_count'])}'),
          _line('Матчи', '${esportsInt(t['matches_count'])}'),
          _line('Live / VOD', 'Доступны из карточек матчей'),
          _line('ИИ', 'Сводный анализ после матчей'),
        ],
      ]),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: AppTypography.captionMedium(color: EsportsColors.muted))),
          Expanded(child: Text(value.trim().isEmpty ? '—' : value, textAlign: TextAlign.right, style: AppTypography.action(color: EsportsColors.text))),
        ]),
      );

  Widget _editor() => _TournamentEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        selectedTeamId: widget.selectedTeamId,
        onClose: () => setState(() => _createMode = false),
        onSaved: (t) async {
          setState(() {
            _createMode = false;
            _selected = t;
          });
          await widget.onRefresh();
        },
      );
}

class _TournamentEditor extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final int? selectedTeamId;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _TournamentEditor({required this.clubId, required this.actorUserId, required this.selectedTeamId, required this.onClose, required this.onSaved});

  @override
  State<_TournamentEditor> createState() => _TournamentEditorState();
}

class _TournamentEditorState extends State<_TournamentEditor> {
  final _name = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _format = TextEditingController(text: 'League');
  String _game = 'EA Sports FC';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    _format.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Введите название турнира.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'club_id': widget.clubId,
      'actor_user_id': widget.actorUserId,
      if ((widget.selectedTeamId ?? 0) > 0) 'team_id': widget.selectedTeamId,
      'name': _name.text.trim(),
      'game_title': _game,
      'format': _format.text.trim(),
      'start_date': _start.text.trim(),
      'end_date': _end.text.trim(),
      'status': 'planned',
    };
    final result = await EsportsApiService.createTournament(payload);
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _saving = false;
        _error = esportsText(result['message'] ?? result['error']).isEmpty ? 'Не удалось создать турнир.' : esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['tournament'] ?? result['data'];
    widget.onSaved(<String, dynamic>{...payload, if (raw is Map) ...Map<String, dynamic>.from(raw)});
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EsportsPanelHeader(title: 'Новый турнир', subtitle: 'Футбольный киберспорт: EA Sports FC / eFootball', trailing: IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded))),
          const SizedBox(height: 16),
          _field(_name, 'Название турнира'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              style: esportsFieldTextStyle(),
              value: _game,
              decoration: esportsInputDecoration('Игра'),
              items: const ['EA Sports FC', 'eFootball'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: esportsFieldTextStyle()))).toList(),
              onChanged: (v) { if (v != null) setState(() => _game = v); },
            ),
          ),
          _field(_format, 'Формат: League / Cup / Group + Playoff'),
          _two(_field(_start, 'Дата начала'), _field(_end, 'Дата окончания')),
          if (_error != null) ...[
            Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(child: EsportsActionButton(icon: Icons.close_rounded, label: 'Отмена', onTap: _saving ? null : widget.onClose, primary: false)),
            const SizedBox(width: 9),
            Expanded(flex: 2, child: EsportsActionButton(icon: Icons.add_rounded, label: _saving ? 'Создаём…' : 'Создать турнир', onTap: _saving ? null : _save)),
          ]),
        ]),
      );

  Widget _field(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, style: esportsFieldTextStyle(), decoration: esportsInputDecoration(label)));
  Widget _two(Widget a, Widget b) => LayoutBuilder(builder: (context, c) => c.maxWidth < 560 ? Column(children: [a, b]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]));
}
