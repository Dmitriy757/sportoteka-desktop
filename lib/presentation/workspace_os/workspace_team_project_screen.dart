import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_records.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_identity.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_project_screen.dart';

class SportotekaTeamProjectScreen extends StatefulWidget {
  const SportotekaTeamProjectScreen({
    super.key,
    required this.team,
    required this.clubId,
    required this.players,
    this.onRefresh,
    this.onOpenModule,
    this.onClose,
  });

  final Map<String, dynamic> team;
  final int clubId;
  final List<Map<String, dynamic>> players;
  final Future<void> Function()? onRefresh;
  final void Function(String moduleKey)? onOpenModule;
  final VoidCallback? onClose;

  @override
  State<SportotekaTeamProjectScreen> createState() => _SportotekaTeamProjectScreenState();
}

class _SportotekaTeamProjectScreenState extends State<SportotekaTeamProjectScreen> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  final _bridge = WorkspaceEntityDataBridge();
  late Map<String, dynamic> _team;

  @override
  void initState() {
    super.initState();
    _team = Map<String, dynamic>.from(widget.team);
  }

  int get _teamId => _bridge.teamId(_team);
  String get _teamName => _bridge.teamName(_team);
  String get _category => _bridge.asString(_team['category'] ?? _team['sport'] ?? _team['age_group'] ?? _team['stage']);

  static const _sections = <_TeamSectionFile>[
    _TeamSectionFile(_TeamSection.card, 'Карточка команды', 'название, категория и основные данные', SportotekaWorkspaceIconKind.teams),
    _TeamSectionFile(_TeamSection.roster, 'Состав', 'игроки команды и их карточки', SportotekaWorkspaceIconKind.players),
    _TeamSectionFile(_TeamSection.matches, 'Матчи', 'игры, результаты и соперники', SportotekaWorkspaceIconKind.matches),
    _TeamSectionFile(_TeamSection.calendar, 'Тренировки и календарь', 'события команды по датам', SportotekaWorkspaceIconKind.calendar),
    _TeamSectionFile(_TeamSection.plans, 'Планы-конспекты', 'планы тренировок команды', SportotekaWorkspaceIconKind.plans),
    _TeamSectionFile(_TeamSection.attendance, 'Посещаемость', 'занятия и журналы посещаемости', SportotekaWorkspaceIconKind.trainings),
    _TeamSectionFile(_TeamSection.testing, 'Тестирование', 'сессии тестов и этапы', SportotekaWorkspaceIconKind.testing),
    _TeamSectionFile(_TeamSection.documents, 'Документы', 'командные файлы и вложения', SportotekaWorkspaceIconKind.documents),
    _TeamSectionFile(_TeamSection.reports, 'Отчёты', 'Tracker, тестирование и посещаемость', SportotekaWorkspaceIconKind.reports),
  ];

  Future<void> _open(_TeamSectionFile file) async {
    final child = file.section == _TeamSection.card ? _cardDocument() : _browser(file);
    await _openWorkspaceChild(child);
  }

  Future<void> _openWorkspaceChild(Widget child) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, __, ___) => Scaffold(backgroundColor: Colors.white, body: SafeArea(child: child)),
        transitionsBuilder: (_, animation, __, routeChild) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: routeChild,
          ),
        ),
      ),
    );
  }

  Widget _cardDocument() {
    final fields = <WorkspaceEntityProperty>[
      WorkspaceEntityProperty('Категория', _category),
      WorkspaceEntityProperty('Возраст / этап', _bridge.asString(_team['age_group'] ?? _team['stage'])),
      WorkspaceEntityProperty('Главный тренер', _bridge.asString(_team['coach_name'] ?? _team['trainer_name'])),
      WorkspaceEntityProperty('Локация', _bridge.asString(_team['location'] ?? _team['venue'] ?? _team['address'])),
      WorkspaceEntityProperty('Создана', _friendlyDate(_bridge.asString(_team['created_at']))),
    ];
    return WorkspaceEntityRecordDocument(
      ownerTitle: _teamName,
      sectionTitle: 'Карточка команды',
      title: 'Основные данные',
      iconKind: SportotekaWorkspaceIconKind.teams,
      record: _team,
      properties: fields,
      noteKey: 'sportoteka_entity_${widget.clubId}_team_${_teamId}',
      legacyNoteKeys: <String>['sportoteka_team_project_${widget.clubId}_${_teamId}_card'],
      entityType: 'team',
      entityId: '$_teamId',
      clubId: widget.clubId,
      serverParentKey: 'entity:team:$_teamId',
      onEdit: _editTeam,
      onRefresh: widget.onRefresh,
    );
  }

  Widget _browser(_TeamSectionFile file) {
    return WorkspaceEntityRecordBrowser(
      ownerTitle: _teamName,
      sectionTitle: file.title,
      iconKind: file.icon,
      loadRecords: () => _loadSection(file.section),
      titleFor: (row) => _titleFor(file.section, row),
      subtitleFor: (row) => _subtitleFor(file.section, row),
      dateFor: (row) => _dateFor(file.section, row),
      propertiesFor: (row) => _propertiesFor(file.section, row),
      localStorageKey: '',
      clubId: widget.clubId,
      serverParentKey: 'team:${_teamId}:${file.section.name}',
      attachmentEntityType: '',
      attachmentEntityId: file.section == _TeamSection.documents ? _teamId : 0,
      attachmentSectionKey: 'documents',
      contextLabel: 'Команда',
      emptyText: file.section == _TeamSection.documents
          ? 'Командных документов пока нет. Когда серверный раздел документов команды будет заполнен, они появятся здесь.'
          : 'В этом разделе пока нет записей.',
      openRecord: (context, row) => _openRecord(file, row),
    );
  }

  Future<List<Map<String, dynamic>>> _loadSection(_TeamSection section) async {
    switch (section) {
      case _TeamSection.roster:
        return _bridge.loadTeamRoster(team: _team, knownPlayers: widget.players);
      case _TeamSection.matches:
        return _bridge.loadTeamMatches(_teamId);
      case _TeamSection.calendar:
      case _TeamSection.attendance:
        return _bridge.loadTeamEvents(_teamId);
      case _TeamSection.plans:
        return _bridge.loadTeamPlans(teamId: _teamId, clubId: widget.clubId);
      case _TeamSection.testing:
        return _bridge.loadTeamTesting(teamId: _teamId, clubId: widget.clubId);
      case _TeamSection.documents:
        final raw = _team['documents'] ?? _team['files'];
        if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        return <Map<String, dynamic>>[];
      case _TeamSection.reports:
        return <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Tracker отчёт команды', 'type': 'Tracker', 'module_key': 'tracker', 'description': 'Физическая и GPS-аналитика команды'},
          <String, dynamic>{'title': 'Отчёт по посещаемости', 'type': 'Посещаемость', 'module_key': 'attendance', 'description': 'Журнал посещаемости и экспорт'},
          <String, dynamic>{'title': 'Отчёт по тестированию', 'type': 'Тестирование', 'module_key': 'testing', 'description': 'Результаты тестов и динамика'},
        ];
      case _TeamSection.card:
        return <Map<String, dynamic>>[];
    }
  }

  String _titleFor(_TeamSection section, Map<String, dynamic> row) {
    switch (section) {
      case _TeamSection.roster:
        final last = _bridge.asString(row['last_name'] ?? row['lastname']);
        final first = _bridge.asString(row['first_name'] ?? row['firstname']);
        final full = _bridge.asString(row['full_name'] ?? row['name']);
        final joined = <String>[last, first].where((e) => e.isNotEmpty).join(' ');
        return joined.isNotEmpty ? joined : (full.isEmpty ? 'Игрок' : full);
      case _TeamSection.matches:
        final opponent = _bridge.asString(row['opponent'] ?? row['opponent_name']);
        return opponent.isEmpty ? 'Матч' : 'Матч — $opponent';
      case _TeamSection.calendar:
      case _TeamSection.attendance:
        return _bridge.asString(row['title'] ?? row['event_title'] ?? row['name']).isEmpty
            ? 'Событие команды'
            : _bridge.asString(row['title'] ?? row['event_title'] ?? row['name']);
      case _TeamSection.plans:
        final value = _bridge.asString(row['theme'] ?? row['title'] ?? row['name']);
        return value.isEmpty ? 'План тренировки' : value;
      case _TeamSection.testing:
        final category = _bridge.asString(row['category']);
        final stage = _bridge.asString(row['stage']);
        return <String>['Тестирование', if (category.isNotEmpty) category, if (stage.isNotEmpty) stage].join(' · ');
      case _TeamSection.documents:
        final value = _bridge.asString(row['title'] ?? row['name'] ?? row['file_name']);
        return value.isEmpty ? 'Документ команды' : value;
      case _TeamSection.reports:
        return _bridge.asString(row['title']);
      case _TeamSection.card:
        return 'Карточка команды';
    }
  }

  String _subtitleFor(_TeamSection section, Map<String, dynamic> row) {
    switch (section) {
      case _TeamSection.roster:
        return <String>[
          _bridge.asString(row['position'] ?? row['amplua']),
          if (_bridge.asString(row['number'] ?? row['shirt_number']).isNotEmpty) '№${_bridge.asString(row['number'] ?? row['shirt_number'])}',
        ].where((e) => e.isNotEmpty).join(' · ');
      case _TeamSection.matches:
        final our = _bridge.asString(row['our_score']);
        final opp = _bridge.asString(row['opponent_score']);
        final score = our.isNotEmpty || opp.isNotEmpty ? '$our:$opp' : '';
        return <String>[_bridge.asString(row['competition_name'] ?? row['event_type']), score].where((e) => e.isNotEmpty).join(' · ');
      case _TeamSection.calendar:
      case _TeamSection.attendance:
        return <String>[_bridge.asString(row['type'] ?? row['event_type']), _bridge.asString(row['location'] ?? row['venue'])].where((e) => e.isNotEmpty).join(' · ');
      case _TeamSection.plans:
        return <String>[_bridge.asString(row['trainer_name'] ?? row['coach_name']), _bridge.asString(row['duration'] ?? row['duration_min'])].where((e) => e.isNotEmpty).join(' · ');
      case _TeamSection.testing:
        return _bridge.asString(row['title'] ?? row['session_name'] ?? row['notes']);
      case _TeamSection.documents:
        return _bridge.asString(row['type'] ?? row['record_type'] ?? row['description']);
      case _TeamSection.reports:
        return _bridge.asString(row['description']);
      case _TeamSection.card:
        return '';
    }
  }

  String _dateFor(_TeamSection section, Map<String, dynamic> row) {
    const keys = <String>['match_date', 'start_at', 'event_date', 'plan_date', 'test_date', 'date', 'created_at', 'uploaded_at'];
    for (final key in keys) {
      final value = _bridge.asString(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<WorkspaceEntityProperty> _propertiesFor(_TeamSection section, Map<String, dynamic> row) {
    final out = <WorkspaceEntityProperty>[];
    void add(String label, dynamic value) {
      final v = _bridge.asString(value);
      if (v.isNotEmpty) out.add(WorkspaceEntityProperty(label, v));
    }
    final date = _dateFor(section, row);
    if (date.isNotEmpty) out.add(WorkspaceEntityProperty('Дата', _friendlyDate(date)));
    switch (section) {
      case _TeamSection.roster:
        add('Амплуа', row['position'] ?? row['amplua']);
        add('Номер', row['number'] ?? row['shirt_number']);
        add('Дата рождения', row['birthday'] ?? row['birth_date']);
        add('Статус', row['status']);
        break;
      case _TeamSection.matches:
        add('Турнир', row['competition_name'] ?? row['event_type']);
        add('Соперник', row['opponent'] ?? row['opponent_name']);
        final our = _bridge.asString(row['our_score']);
        final opp = _bridge.asString(row['opponent_score']);
        if (our.isNotEmpty || opp.isNotEmpty) out.add(WorkspaceEntityProperty('Счёт', '$our:$opp'));
        add('Место', row['stadium'] ?? row['location']);
        break;
      case _TeamSection.calendar:
      case _TeamSection.attendance:
        add('Тип', row['type'] ?? row['event_type']);
        add('Место', row['location'] ?? row['venue'] ?? row['address']);
        add('Статус', row['status']);
        break;
      case _TeamSection.plans:
        add('Тренер', row['trainer_name'] ?? row['coach_name']);
        add('Тема', row['theme'] ?? row['title']);
        add('Длительность', row['duration'] ?? row['duration_min']);
        break;
      case _TeamSection.testing:
        add('Категория', row['category']);
        add('Этап', row['stage']);
        add('Автор', row['created_by_name'] ?? row['created_by']);
        break;
      case _TeamSection.documents:
        add('Тип', row['type'] ?? row['record_type']);
        add('Автор', row['author'] ?? row['created_by_name']);
        add('Обновлено', row['updated_at'] ?? row['created_at']);
        break;
      case _TeamSection.reports:
        add('Тип', row['type']);
        add('Раздел', row['description']);
        break;
      case _TeamSection.card:
        break;
    }
    return out;
  }

  Future<void> _openRecord(_TeamSectionFile file, Map<String, dynamic> row) async {
    if (file.section == _TeamSection.roster) {
      final player = Map<String, dynamic>.from(row);
      player['team_id'] ??= _teamId;
      player['team_name'] ??= _teamName;
      await _openWorkspaceChild(
        SportotekaPlayerProjectScreen(
          player: player,
          clubId: widget.clubId,
          teamId: _teamId,
          teamName: _teamName,
          onRefresh: widget.onRefresh,
        ),
      );
      return;
    }
    final moduleKey = _bridge.asString(row['module_key']);
    final fileUrl = _findFileUrl(row);
    final identity = WorkspaceEntityIdentity.resolve(
      clubId: widget.clubId,
      record: row,
      sectionHint: file.section.name,
      fallbackType: 'team_${file.section.name}',
      fallbackId: '${_teamId}_${_recordKey(row)}',
    );
    final legacyKey = 'sportoteka_team_${_teamId}_${file.section.name}_${_recordKey(row)}';
    final doc = WorkspaceEntityRecordDocument(
      ownerTitle: _teamName,
      sectionTitle: file.title,
      title: _titleFor(file.section, row),
      iconKind: file.icon,
      record: row,
      properties: _propertiesFor(file.section, row),
      noteKey: identity.key,
      legacyNoteKeys: <String>[legacyKey],
      entityType: identity.type,
      entityId: identity.id,
      clubId: widget.clubId,
      serverParentKey: 'entity:${identity.type}:${identity.id}',
      fileUrl: fileUrl,
      onRefresh: widget.onRefresh,
      onEdit: moduleKey.isNotEmpty && widget.onOpenModule != null
          ? () async => widget.onOpenModule!(moduleKey)
          : null,
    );
    await _openWorkspaceChild(doc);
  }

  Future<void> _editTeam() async {
    final name = TextEditingController(text: _teamName);
    final category = TextEditingController(text: _category);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Редактировать команду', style: AppTypography.sectionTitle(color: _text)),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Название команды')),
            const SizedBox(height: 10),
            TextField(controller: category, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Категория')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Отмена', style: AppTypography.action(color: _muted))),
          FilledButton(
            onPressed: () async {
              final ok = await _bridge.saveTeamProfile(team: _team, name: name.text, category: category.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, ok);
            },
            style: FilledButton.styleFrom(backgroundColor: _green),
            child: Text('Сохранить', style: AppTypography.actionStrong(color: Colors.white)),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _team['name'] = name.text.trim();
        _team['team_name'] = name.text.trim();
        _team['category'] = category.text.trim();
      });
      await widget.onRefresh?.call();
    }
  }

  String _recordKey(Map<String, dynamic> row) {
    for (final key in const <String>['id', 'match_id', 'event_id', 'plan_id', 'session_id', 'date', 'created_at']) {
      final value = _bridge.asString(row[key]);
      if (value.isNotEmpty) return '$key:$value'.replaceAll(RegExp(r'[^a-zA-Z0-9_:-]+'), '_');
    }
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _findFileUrl(Map<String, dynamic> row) {
    for (final key in const <String>['file_url', 'file', 'url', 'document_url', 'pdf_url']) {
      final value = _bridge.asString(row[key]);
      if (value.startsWith('http://') || value.startsWith('https://')) return value;
    }
    return '';
  }

  String _friendlyDate(String raw) {
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 620;
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: mobile ? 62 : 70,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  IconButton(onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(), icon: const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.back, size: 20)),
                  const SizedBox(width: 4),
                  const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.teams, size: 38),
                  const SizedBox(width: 10),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _text)),
                    Text(<String>['Команда', if (_category.isNotEmpty) _category].join(' · '), style: AppTypography.secondary(color: _muted)),
                  ])),
                ]),
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(mobile ? 12 : 20, 12, mobile ? 12 : 20, 8),
                      child: Row(
                        children: [
                          Text('Разделы', style: AppTypography.sectionTitle(color: _text)),
                          const SizedBox(width: 8),
                          const _TeamBrandDots(),
                          const Spacer(),
                          Text('${_sections.length} разделов', style: AppTypography.caption(color: _teamProjectMuted)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(mobile ? 8 : 14, 0, mobile ? 8 : 14, 20),
                        itemCount: _sections.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 54, color: _teamProjectLine),
                        itemBuilder: (_, index) {
                          final file = _sections[index];
                          return _TeamFolderTile(file: file, mobile: mobile, onTap: () => _open(file));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _line))),
                child: Row(children: [Text('${_sections.length} разделов', style: AppTypography.caption(color: _teamProjectMuted)), const Spacer(), Text('SPORTOTEKA OS · TEAM', style: AppTypography.menuGroup(color: _muted))]),
              ),
            ],
          ),
        );
      },
    );
  }
}


const _teamProjectGreen = Color(0xFF0B8F55);
const _teamProjectText = Color(0xFF101814);
const _teamProjectMuted = Color(0xFF758079);
const _teamProjectLine = Color(0xFFE7EAE7);

class _TeamFolderTile extends StatelessWidget {
  const _TeamFolderTile({required this.file, required this.mobile, required this.onTap});
  final dynamic file;
  final bool mobile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 10, vertical: mobile ? 7 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const _TeamFolderIcon(size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _teamProjectText))),
                        const SizedBox(width: 6),
                        const _TeamBrandDots(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(file.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _teamProjectMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 17, color: _teamProjectMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamFolderIcon extends StatelessWidget {
  const _TeamFolderIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .25),
        decoration: const BoxDecoration(color: Color(0xFFF1F4F2), shape: BoxShape.circle),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2.4,
          crossAxisSpacing: 2.4,
          children: List.generate(
            9,
            (index) => DecoratedBox(
              decoration: BoxDecoration(
                color: index == 1 || index == 4 || index == 8 ? const Color(0xFF0B8F55) : const Color(0xFFC7D2CC),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

class _TeamBrandDots extends StatelessWidget {
  const _TeamBrandDots();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == 1 ? const Color(0xFF17A36A) : const Color(0xFFB8D9C6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

enum _TeamSection { card, roster, matches, calendar, plans, attendance, testing, documents, reports }

class _TeamSectionFile {
  const _TeamSectionFile(this.section, this.title, this.subtitle, this.icon);
  final _TeamSection section;
  final String title;
  final String subtitle;
  final SportotekaWorkspaceIconKind icon;
}
