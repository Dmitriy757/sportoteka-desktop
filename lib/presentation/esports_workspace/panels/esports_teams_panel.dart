import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsTeamsPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onSelectTeam;
  final Future<void> Function() onRefresh;
  final bool canManage;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenMatches;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenStaff;

  const EsportsTeamsPanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.clubName,
    required this.teams,
    required this.selectedTeamId,
    required this.onSelectTeam,
    required this.onRefresh,
    required this.canManage,
    this.onOpenRoster,
    this.onOpenMatches,
    this.onOpenCalendar,
    this.onOpenStaff,
  });

  @override
  State<EsportsTeamsPanel> createState() => _EsportsTeamsPanelState();
}

class _EsportsTeamsPanelState extends State<EsportsTeamsPanel> {
  final TextEditingController _search = TextEditingController();
  bool _createMode = false;
  Map<String, dynamic>? _localSelected;
  String _filter = 'Все';

  @override
  void initState() {
    super.initState();
    _search.addListener(_rebuild);
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant EsportsTeamsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTeamId != widget.selectedTeamId ||
        oldWidget.teams.length != widget.teams.length) {
      _syncSelection();
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _syncSelection() {
    Map<String, dynamic>? next;
    for (final team in widget.teams) {
      if (_id(team) == widget.selectedTeamId) {
        next = team;
        break;
      }
    }
    next ??= widget.teams.isNotEmpty ? widget.teams.first : null;
    _localSelected = next;
  }

  @override
  void dispose() {
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  int _id(Map<String, dynamic> m) =>
      esportsInt(m['id'] ?? m['team_id'] ?? m['teamId']);

  String _name(Map<String, dynamic> m) {
    final value = esportsText(m['name'] ?? m['team_name'] ?? m['title']);
    return value.isEmpty ? 'Киберспортивная команда' : value;
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return widget.teams.where((team) {
      final game = esportsText(team['game_title'] ?? team['game']);
      final live = esportsBool(team['live'] ?? team['is_live']);
      final status = esportsText(team['status']).toLowerCase();
      if (_filter == 'EA Sports FC' && game != 'EA Sports FC') return false;
      if (_filter == 'eFootball' && game != 'eFootball') return false;
      if (_filter == 'LIVE' && !live) return false;
      if (_filter == 'Активные' && status.isNotEmpty && !{'active', 'enabled', 'current'}.contains(status)) return false;
      if (q.isEmpty) return true;
      final hay = [
        _name(team),
        game,
        esportsText(team['game_mode'] ?? team['mode']),
        esportsText(team['platform']),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < 680;
        if (phone) return _buildPhone();
        final leftWidth = c.maxWidth < 980 ? 320.0 : 410.0;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: esportsCardDecoration(radius: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: leftWidth, child: _buildListPane()),
                  const SizedBox(width: 1, child: ColoredBox(color: EsportsColors.line)),
                  Expanded(child: _buildRightPane()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhone() {
    if (_createMode) {
      return _TeamEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        onClose: () => setState(() => _createMode = false),
        onSaved: (_) async {
          setState(() => _createMode = false);
          await widget.onRefresh();
        },
      );
    }
    if (_localSelected != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _mobileToolbar(),
          const SizedBox(height: 10),
          _teamDetails(_localSelected!),
          const SizedBox(height: 12),
          EsportsActionButton(
            icon: Icons.list_alt_rounded,
            label: 'Показать список команд',
            onTap: () => setState(() => _localSelected = null),
            primary: false,
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: _mobileToolbar()),
        Expanded(child: _teamList()),
      ],
    );
  }

  Widget _mobileToolbar() => Row(
        children: [
          Expanded(
            child: EsportsPanelHeader(
              title: 'Команды',
              subtitle: '${widget.teams.length} киберспортивных команд',
            ),
          ),
          if (widget.canManage)
            IconButton(
              onPressed: () => setState(() => _createMode = true),
              icon: const Icon(Icons.add_rounded, color: EsportsColors.greenDark),
            ),
        ],
      );

  Widget _buildListPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: EsportsPanelHeader(
            title: 'Команды',
            subtitle: 'EA Sports FC и eFootball',
            trailing: widget.canManage
                ? EsportsActionButton(
                    icon: Icons.add_rounded,
                    label: 'Создать',
                    onTap: () => setState(() => _createMode = true),
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _search,
            style: esportsFieldTextStyle(),
            decoration: esportsInputDecoration('Поиск команды', icon: Icons.search_rounded),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            children: [
              for (final value in const ['Все', 'EA Sports FC', 'eFootball', 'Активные', 'LIVE']) ...[
                _teamFilterChip(value),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: EsportsColors.line),
        Expanded(child: _teamList()),
      ],
    );
  }

  Widget _teamFilterChip(String value) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? EsportsColors.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? EsportsColors.green.withOpacity(.18) : Colors.transparent,
            width: .7,
          ),
        ),
        child: Text(
          value,
          style: AppTypography.custom(
            size: 10.8,
            weight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? EsportsColors.greenDark : EsportsColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _teamList() {
    final list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.teams.isEmpty ? 'Киберкоманд пока нет' : 'Ничего не найдено',
            style: AppTypography.captionMedium(color: EsportsColors.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, index) {
        final team = list[index];
        final active = _id(team) == _id(_localSelected ?? const {});
        return Material(
          color: active ? EsportsColors.greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: () {
              setState(() {
                _createMode = false;
                _localSelected = team;
              });
              widget.onSelectTeam(team);
            },
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : EsportsColors.soft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.groups_2_outlined, color: EsportsColors.greenDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(team),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.action(color: EsportsColors.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            esportsText(team['game_title'] ?? team['game']),
                            esportsText(team['game_mode'] ?? team['mode']),
                            if (esportsInt(team['players_count'] ?? team['athletes_count']) > 0)
                              '${esportsInt(team['players_count'] ?? team['athletes_count'])} игроков',
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

  Widget _buildRightPane() {
    if (_createMode) {
      return _TeamEditor(
        clubId: widget.clubId,
        actorUserId: widget.userId,
        onClose: () => setState(() => _createMode = false),
        onSaved: (team) async {
          setState(() {
            _createMode = false;
            _localSelected = team;
          });
          await widget.onRefresh();
        },
      );
    }
    if (_localSelected == null) {
      return EsportsEmptyState(
        icon: Icons.groups_2_outlined,
        title: widget.teams.isEmpty ? 'Создайте первую киберкоманду' : 'Выберите команду',
        text: widget.teams.isEmpty
            ? 'Команда создаётся внутри Sportoteka Esports и не попадает в футбольный список команд.'
            : 'Справа появятся состав, ближайший матч, Live и параметры команды.',
        action: widget.canManage
            ? EsportsActionButton(
                icon: Icons.add_rounded,
                label: 'Создать команду',
                onTap: () => setState(() => _createMode = true),
              )
            : null,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
      child: _teamDetails(_localSelected!),
    );
  }

  Widget _teamDetails(Map<String, dynamic> team) {
    final members = esportsInt(team['players_count'] ?? team['athletes_count']);
    final matches = esportsInt(team['matches_count']);
    final tournaments = esportsInt(team['tournaments_count']);
    final live = esportsBool(team['live'] ?? team['is_live']);
    final game = esportsText(team['game_title'] ?? team['game']);
    final mode = esportsText(team['game_mode'] ?? team['mode']);
    final platform = esportsText(team['platform']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: EsportsColors.greenSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _initials(_name(team)),
                style: AppTypography.custom(
                  size: 19,
                  weight: FontWeight.w700,
                  color: EsportsColors.greenDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: EsportsColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Активная команда',
                        style: AppTypography.custom(
                          size: 10.2,
                          weight: FontWeight.w600,
                          color: EsportsColors.greenDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _name(team),
                    style: AppTypography.custom(
                      size: 20,
                      weight: FontWeight.w700,
                      color: EsportsColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [game, mode, platform].where((e) => e.isNotEmpty).join(' · '),
                    style: AppTypography.captionMedium(color: EsportsColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Действия команды',
              onPressed: () {},
              icon: const Icon(Icons.more_horiz_rounded, color: EsportsColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _teamActionRow(
          icon: Icons.account_tree_rounded,
          title: 'Открыть рабочую область команды',
          subtitle: 'Состав · Матчи · Турниры · Live · Видео · ИИ',
          primary: true,
          onTap: widget.onOpenRoster,
        ),
        const SizedBox(height: 4),
        _teamActionRow(
          icon: Icons.groups_2_rounded,
          title: 'Состав команды',
          subtitle: '$members киберспортсменов · игровые профили и роли',
          onTap: widget.onOpenRoster,
        ),
        _teamActionRow(
          icon: Icons.sports_esports_rounded,
          title: 'Матчи',
          subtitle: 'Расписание, результаты, VOD и Live',
          onTap: widget.onOpenMatches,
        ),
        _teamActionRow(
          icon: Icons.calendar_month_rounded,
          title: 'Календарь',
          subtitle: 'Матчи, турниры, эфиры и события',
          onTap: widget.onOpenCalendar,
        ),
        if (widget.onOpenStaff != null)
          _teamActionRow(
            icon: Icons.badge_outlined,
            title: 'Staff команды',
            subtitle: 'Тренеры, аналитики, менеджеры и доступы',
            onTap: widget.onOpenStaff,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _miniMetric('$members', 'Киберспортсмены')),
            const SizedBox(width: 1),
            Expanded(child: _miniMetric('$matches', 'Матчи')),
            const SizedBox(width: 1),
            Expanded(child: _miniMetric('$tournaments', 'Турниры')),
            const SizedBox(width: 1),
            Expanded(child: _miniMetric(live ? '1' : '0', 'Сейчас в эфире')),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EsportsColors.greenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 42, decoration: BoxDecoration(color: EsportsColors.green, borderRadius: BorderRadius.circular(99))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Описание команды', style: AppTypography.action(color: EsportsColors.text)),
                    const SizedBox(height: 4),
                    Text(
                      esportsText(team['description']).isEmpty
                          ? 'Описание пока не заполнено. Его можно добавить в настройках киберкоманды.'
                          : esportsText(team['description']),
                      style: AppTypography.captionMedium(color: EsportsColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (words.isEmpty) return 'ES';
    if (words.length == 1) return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Widget _teamActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? EsportsColors.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: primary ? EsportsColors.green : const Color(0xFFC8CDD3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: primary ? EsportsColors.greenDark : const Color(0xFF344054)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.action(color: EsportsColors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.captionMedium(color: EsportsColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: EsportsColors.subtle),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String value, String label) => Container(
        height: 66,
        alignment: Alignment.center,
        color: const Color(0xFFFAFBFA),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.subsectionTitle(color: EsportsColors.text)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ],
        ),
      );
}

class _TeamEditor extends StatefulWidget {
  final int clubId;
  final int actorUserId;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _TeamEditor({
    required this.clubId,
    required this.actorUserId,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends State<_TeamEditor> {
  final _name = TextEditingController();
  final _region = TextEditingController(text: 'Europe');
  final _season = TextEditingController();
  final _description = TextEditingController();
  String _game = 'EA Sports FC';
  String _mode = 'Clubs';
  String _platform = 'Cross-platform';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _season.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Введите название киберкоманды.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'club_id': widget.clubId,
      'actor_user_id': widget.actorUserId,
      'name': _name.text.trim(),
      'team_name': _name.text.trim(),
      'game_title': _game,
      'game_mode': _mode,
      'platform': _platform,
      'region': _region.text.trim(),
      'season': _season.text.trim(),
      'description': _description.text.trim(),
      'direction': 'football_esports',
    };
    final result = await EsportsApiService.createTeam(payload);
    if (!mounted) return;
    if (result['success'] != true && result['status'] != 'success') {
      setState(() {
        _saving = false;
        _error = esportsText(result['message'] ?? result['error']).isEmpty
            ? 'Не удалось создать команду. Проверьте Esports API.'
            : esportsText(result['message'] ?? result['error']);
      });
      return;
    }
    final raw = result['team'] ?? result['data'];
    final team = <String, dynamic>{
      ...payload,
      if (raw is Map) ...Map<String, dynamic>.from(raw),
    };
    widget.onSaved(team);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EsportsPanelHeader(
            title: 'Новая киберспортивная команда',
            subtitle: 'Команда будет создана только внутри Sportoteka Esports',
            trailing: IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded)),
          ),
          const SizedBox(height: 16),
          _field(_name, 'Название команды', Icons.groups_2_outlined),
          _two(
            _dropdown('Игра', _game, const ['EA Sports FC', 'eFootball'], (v) => setState(() => _game = v)),
            _dropdown('Режим', _mode, const ['1×1', '2×2', 'Clubs', 'Ultimate Team', 'Командный'], (v) => setState(() => _mode = v)),
          ),
          _two(
            _dropdown('Платформа', _platform, const ['Cross-platform', 'PlayStation 5', 'Xbox Series', 'PC', 'Nintendo Switch'], (v) => setState(() => _platform = v)),
            _field(_region, 'Регион', Icons.public_rounded),
          ),
          _field(_season, 'Сезон', Icons.calendar_month_outlined),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _description,
              style: esportsFieldTextStyle(),
              maxLines: 4,
              decoration: esportsInputDecoration('Описание команды', icon: Icons.notes_rounded),
            ),
          ),
          if (_error != null) ...[
            Text(_error!, style: AppTypography.custom(size: 11, weight: FontWeight.w500, color: EsportsColors.red)),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: EsportsActionButton(
                  icon: Icons.close_rounded,
                  label: 'Отмена',
                  onTap: _saving ? null : widget.onClose,
                  primary: false,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: EsportsActionButton(
                  icon: Icons.add_rounded,
                  label: _saving ? 'Создаём…' : 'Создать команду',
                  onTap: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, style: esportsFieldTextStyle(), decoration: esportsInputDecoration(label, icon: icon)),
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
