import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_records.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_identity.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_team_project_screen.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';

class SportotekaTrainerProjectScreen extends StatefulWidget {
  const SportotekaTrainerProjectScreen({
    super.key,
    required this.trainer,
    required this.clubId,
    required this.teams,
    required this.players,
    this.onRefresh,
    this.onClose,
    this.currentUserId = 0,
  });

  final Map<String, dynamic> trainer;
  final int clubId;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onClose;
  final int currentUserId;

  @override
  State<SportotekaTrainerProjectScreen> createState() => _SportotekaTrainerProjectScreenState();
}

class _SportotekaTrainerProjectScreenState extends State<SportotekaTrainerProjectScreen> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);

  final _bridge = WorkspaceEntityDataBridge();
  late Map<String, dynamic> _trainer;

  @override
  void initState() {
    super.initState();
    _trainer = Map<String, dynamic>.from(widget.trainer);
    _ensureDocumentsFolder();
    _refreshProfile();
  }

  int get _trainerId => _bridge.trainerId(_trainer);

  String get _trainerName {
    final last = _bridge.asString(_trainer['last_name'] ?? _trainer['lastname']);
    final first = _bridge.asString(_trainer['first_name'] ?? _trainer['firstname']);
    final full = _bridge.asString(_trainer['full_name'] ?? _trainer['name']);
    final joined = <String>[last, first].where((e) => e.isNotEmpty).join(' ');
    return joined.isNotEmpty ? joined : (full.isEmpty ? 'Тренер' : full);
  }

  String get _role => _bridge.asString(
        _trainer['position'] ?? _trainer['role_title'] ?? _trainer['specialization'] ?? _trainer['role'],
      );

  Future<void> _refreshProfile() async {
    final loaded = await _bridge.loadTrainerProfile(_trainer);
    if (!mounted) return;
    setState(() => _trainer = loaded);
    await _ensureDocumentsFolder();
  }

  String get _documentsFolderId =>
      'local-folder:trainer-documents:$_trainerId';

  WorkspaceServerStorage get _workspaceStorage => WorkspaceServerStorage(
        clubId: widget.clubId,
        userId: widget.currentUserId,
      );

  Future<void> _ensureDocumentsFolder() async {
    if (_trainerId <= 0 || widget.clubId <= 0) return;

    try {
      final storage = _workspaceStorage;
      final snapshot = await storage.load();
      final existing =
          snapshot.nodes.where((node) => node.id == _documentsFolderId);

      final folder = WorkspaceFinderNode(
        id: _documentsFolderId,
        title: 'Документы · $_trainerName',
        subtitle: 'Документы тренера',
        kind: WorkspaceFinderNodeKind.folder,
        parentId: 'documents',
        payload: <String, dynamic>{
          '_trainer_documents_folder': true,
          'trainer_id': _trainerId,
          'trainer_name': _trainerName,
          'club_id': widget.clubId,
        },
        updatedAt: DateTime.now(),
      );

      if (existing.isEmpty) {
        await storage.createNode(folder);
      } else {
        final old = existing.first;
        if (old.title != folder.title ||
            old.subtitle != folder.subtitle ||
            old.parentId != folder.parentId) {
          await storage.updateNode(folder);
        }
      }
    } catch (_) {
      // Workspace-связь вспомогательная и не должна блокировать профиль.
    }
  }

  String _documentTitle(Map<String, dynamic> row) {
    final value = _bridge.asString(
      row['title'] ??
          row['name'] ??
          row['file_name'] ??
          row['document_type'] ??
          row['type'],
    );
    return value.isEmpty ? 'Документ' : value;
  }

  String _documentSubtitle(Map<String, dynamic> row) {
    final type = _bridge.asString(
      row['document_type'] ??
          row['type'] ??
          row['record_type'],
    );
    final number = _bridge.asString(
      row['document_number'] ??
          row['number'],
    );
    return <String>[
      if (type.isNotEmpty) type,
      if (number.isNotEmpty) '№ $number',
    ].join(' · ');
  }

  String _documentFileUrl(Map<String, dynamic> row) {
    final raw = _bridge.asString(
      row['file_url'] ??
          row['document_url'] ??
          row['file'] ??
          row['url'] ??
          row['pdf_url'],
    );
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  String _documentMirrorId(Map<String, dynamic> row, int index) {
    final id = _bridge.asInt(
      row['id'] ??
          row['record_id'] ??
          row['document_id'],
    );
    if (id > 0) return 'trainer-hr-document:$_trainerId:$id';

    final raw =
        '${_documentTitle(row)}|${_bridge.asString(row['created_at'] ?? row['issue_date'])}|$index'
            .toLowerCase()
            .replaceAll(
              RegExp(r'[^a-z0-9а-яё_-]+', caseSensitive: false),
              '_',
            );
    final safe = raw.length > 80 ? raw.substring(0, 80) : raw;
    return 'trainer-hr-document:$_trainerId:$safe';
  }

  Future<void> _syncDocumentsFolder(
    List<Map<String, dynamic>> rows,
  ) async {
    if (_trainerId <= 0 || widget.clubId <= 0) return;

    try {
      await _ensureDocumentsFolder();
      final storage = _workspaceStorage;
      final snapshot = await storage.load();
      final existing = <String, WorkspaceFinderNode>{
        for (final node in snapshot.nodes)
          if (node.parentId == _documentsFolderId &&
              node.payload?['_trainer_hr_mirror'] == true)
            node.id: node,
      };

      final wanted = <String>{};

      for (var index = 0; index < rows.length; index++) {
        final row = Map<String, dynamic>.from(rows[index]);
        final nodeId = _documentMirrorId(row, index);
        wanted.add(nodeId);

        final node = WorkspaceFinderNode(
          id: nodeId,
          title: _documentTitle(row),
          subtitle: _documentSubtitle(row),
          kind: WorkspaceFinderNodeKind.document,
          parentId: _documentsFolderId,
          payload: <String, dynamic>{
            ...row,
            '_workspace_real_record': true,
            '_trainer_hr_mirror': true,
            '_workspace_owner': _trainerName,
            'trainer_id': _trainerId,
            'club_id': widget.clubId,
            if (_documentFileUrl(row).isNotEmpty)
              'file_url': _documentFileUrl(row),
          },
          updatedAt: DateTime.tryParse(
                _bridge
                    .asString(
                      row['updated_at'] ??
                          row['created_at'] ??
                          row['issue_date'],
                    )
                    .replaceFirst(' ', 'T'),
              ) ??
              DateTime.now(),
        );

        if (existing.containsKey(nodeId)) {
          await storage.updateNode(node);
        } else {
          await storage.createNode(node);
        }
      }

      for (final stale in existing.keys) {
        if (!wanted.contains(stale)) {
          await storage.deleteNode(stale);
        }
      }
    } catch (_) {
      // Основной список документов остаётся доступным даже без Workspace.
    }
  }

  Future<List<Map<String, dynamic>>> _loadTrainerDocumentsLinked() async {
    final rows = await _bridge.loadTrainerDocuments(
      trainerId: _trainerId,
      clubId: widget.clubId,
    );
    await _syncDocumentsFolder(rows);
    return rows;
  }

  Future<void> _uploadTrainerDocumentsLinked(List<String> paths) async {
    await _bridge.uploadTrainerDocuments(
      trainerId: _trainerId,
      clubId: widget.clubId,
      filePaths: paths,
    );
    final rows = await _bridge.loadTrainerDocuments(
      trainerId: _trainerId,
      clubId: widget.clubId,
    );
    await _syncDocumentsFolder(rows);
    await widget.onRefresh?.call();
  }

  static const _sections = <_TrainerSectionFile>[
    _TrainerSectionFile(_TrainerSection.card, 'Карточка тренера', 'контакты, специализация и профиль', SportotekaWorkspaceIconKind.trainers),
    _TrainerSectionFile(_TrainerSection.work, 'Команды и локации', 'назначения и рабочие места', SportotekaWorkspaceIconKind.teams),
    _TrainerSectionFile(_TrainerSection.schedule, 'Расписание', 'тренировки, матчи и события', SportotekaWorkspaceIconKind.calendar),
    _TrainerSectionFile(_TrainerSection.attendance, 'Посещаемость', 'рабочие отметки по датам', SportotekaWorkspaceIconKind.trainings),
    _TrainerSectionFile(_TrainerSection.plans, 'Планы-конспекты', 'созданные планы тренировок', SportotekaWorkspaceIconKind.plans),
    _TrainerSectionFile(_TrainerSection.testing, 'Тестирование', 'сессии команд тренера', SportotekaWorkspaceIconKind.testing),
    _TrainerSectionFile(_TrainerSection.health, 'Здоровье', 'медицинские записи и допуски', SportotekaWorkspaceIconKind.medical),
    _TrainerSectionFile(_TrainerSection.documents, 'Документы', 'договоры, сертификаты и файлы', SportotekaWorkspaceIconKind.documents),
  ];

  Future<void> _open(_TrainerSectionFile file) async {
    // В проекте тренера каждый раздел ведёт себя именно как папка.
    // Документы остаются файлами внутри своей папки, а реальные данные
    // (расписание, посещаемость, тестирование и т.д.) сначала
    // раскладываются по автоматически созданным подпапкам.
    final child = file.section == _TrainerSection.documents
        ? _browser(file)
        : _folderBrowser(file);
    await _openChild(child);
  }

  Future<void> _openChild(Widget child) async {
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
    return WorkspaceEntityRecordDocument(
      ownerTitle: _trainerName,
      sectionTitle: 'Карточка тренера',
      title: 'Основные данные',
      iconKind: SportotekaWorkspaceIconKind.trainers,
      record: _trainer,
      properties: <WorkspaceEntityProperty>[
        WorkspaceEntityProperty('Должность', _role),
        WorkspaceEntityProperty('Специализация', _bridge.asString(_trainer['specialization'] ?? _trainer['speciality'])),
        WorkspaceEntityProperty('Телефон', _bridge.asString(_trainer['phone'] ?? _trainer['phone_number'])),
        WorkspaceEntityProperty('Email', _bridge.asString(_trainer['email'])),
        WorkspaceEntityProperty('Город', _bridge.asString(_trainer['city'] ?? _trainer['town'])),
        WorkspaceEntityProperty('Опыт', _bridge.asString(_trainer['experience'] ?? _trainer['work_experience'])),
      ],
      noteKey: 'sportoteka_entity_${widget.clubId}_trainer_${_trainerId}',
      legacyNoteKeys: <String>['sportoteka_trainer_project_${widget.clubId}_${_trainerId}_card'],
      entityType: 'trainer',
      entityId: '$_trainerId',
      clubId: widget.clubId,
      currentUserId: widget.currentUserId,
      serverParentKey: 'entity:trainer:$_trainerId',
      onEdit: _editTrainer,
      onRefresh: () async {
        await _refreshProfile();
        await widget.onRefresh?.call();
      },
    );
  }

  Widget _browser(_TrainerSectionFile file) {
    return WorkspaceEntityRecordBrowser(
      ownerTitle: _trainerName,
      sectionTitle: file.title,
      iconKind: file.icon,
      loadRecords: () => _loadSection(file.section),
      titleFor: (row) => _titleFor(file.section, row),
      subtitleFor: (row) => _subtitleFor(file.section, row),
      dateFor: (row) => _dateFor(file.section, row),
      propertiesFor: (row) => _propertiesFor(file.section, row),
      localStorageKey: '',
      clubId: widget.clubId,
      currentUserId: widget.currentUserId,
      serverParentKey: file.section == _TrainerSection.documents
          ? _documentsFolderId
          : 'trainer:${_trainerId}:${file.section.name}',
      allowCreateDocuments: true,
      attachmentEntityType:
          file.section == _TrainerSection.documents ? '' : 'trainer',
      attachmentEntityId: _trainerId,
      attachmentSectionKey: file.section.name,
      externalUploadPaths: file.section == _TrainerSection.documents
          ? _uploadTrainerDocumentsLinked
          : null,
      contextLabel: 'Тренер',
      openRecord: (context, row) => _openRecord(file, row),
      emptyText: 'В этой папке пока нет документов.',
    );
  }

  Widget _folderBrowser(_TrainerSectionFile file) {
    return _TrainerSectionFolderBrowser(
      ownerTitle: _trainerName,
      sectionTitle: file.title,
      sectionIcon: file.icon,
      trainerId: _trainerId,
      clubId: widget.clubId,
      currentUserId: widget.currentUserId,
      sectionKey: file.section.name,
      loadRows: () => _loadSection(file.section),
      folderKeyFor: (row) => _folderKeyFor(file.section, row),
      folderTitleFor: (rows) => _folderTitleFor(file.section, rows),
      folderSubtitleFor: (rows) => _folderSubtitleFor(file.section, rows),
      onOpenFolder: (folder) => _openAutoFolder(file, folder),
      onOpenSectionDocuments: () => _openSectionDocuments(file),
    );
  }

  Future<void> _openSectionDocuments(_TrainerSectionFile file) async {
    final child = WorkspaceEntityRecordBrowser(
      ownerTitle: _trainerName,
      sectionTitle: '${file.title} · Документы',
      iconKind: SportotekaWorkspaceIconKind.documents,
      loadRecords: () async => <Map<String, dynamic>>[],
      titleFor: (row) => _bridge.asString(row['title'] ?? row['name']),
      subtitleFor: (row) => _bridge.asString(row['subtitle'] ?? row['description']),
      dateFor: (row) => _bridge.asString(row['updated_at'] ?? row['created_at']),
      propertiesFor: (row) => <WorkspaceEntityProperty>[
        WorkspaceEntityProperty('Раздел', file.title),
      ],
      localStorageKey: '',
      clubId: widget.clubId,
      currentUserId: widget.currentUserId,
      serverParentKey: 'trainer:${_trainerId}:${file.section.name}',
      allowCreateDocuments: true,
      attachmentEntityType: 'trainer',
      attachmentEntityId: _trainerId,
      attachmentSectionKey: '${file.section.name}:root',
      contextLabel: 'Тренер',
      emptyText: 'В папке пока нет документов. Можно создать документ или добавить файл.',
      openRecord: (context, row) async {},
    );
    await _openChild(child);
  }

  Future<void> _openAutoFolder(
    _TrainerSectionFile file,
    _TrainerAutoFolder folder,
  ) async {
    final child = WorkspaceEntityRecordBrowser(
      ownerTitle: _trainerName,
      sectionTitle: folder.title,
      iconKind: file.icon,
      loadRecords: () async => folder.rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      titleFor: (row) => _titleFor(file.section, row),
      subtitleFor: (row) => _subtitleFor(file.section, row),
      dateFor: (row) => _dateFor(file.section, row),
      propertiesFor: (row) => _propertiesFor(file.section, row),
      localStorageKey: '',
      clubId: widget.clubId,
      currentUserId: widget.currentUserId,
      serverParentKey: folder.serverParentKey,
      allowCreateDocuments: true,
      attachmentEntityType: 'trainer',
      attachmentEntityId: _trainerId,
      attachmentSectionKey: '${file.section.name}:${folder.key}',
      contextLabel: 'Тренер',
      openRecord: (context, row) => _openRecord(file, row),
      emptyText: 'Папка пустая. Здесь можно создать документ или добавить файл.',
    );
    await _openChild(child);
  }

  String _folderKeyFor(_TrainerSection section, Map<String, dynamic> row) {
    String safe(String value) {
      final normalized = value
          .toLowerCase()
          .replaceAll('ё', 'е')
          .replaceAll(RegExp(r'[^a-z0-9а-я_-]+', caseSensitive: false), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      return normalized.isEmpty ? 'item' : normalized;
    }

    if (section == _TrainerSection.card) return 'profile';

    if (section == _TrainerSection.work) {
      if (row['_trainer_location_folder'] == true) {
        final location = _bridge.asString(
          row['location'] ?? row['venue'] ?? row['address'] ?? row['name'],
        );
        return 'location:${safe(location)}';
      }
      final teamId = _bridge.teamId(row);
      if (teamId > 0) return 'team:$teamId';
      return 'team:${safe(_bridge.teamName(row))}';
    }

    final dateRaw = _dateFor(section, row);
    final date = DateTime.tryParse(dateRaw.replaceFirst(' ', 'T'));
    if (date != null) {
      String two(int value) => value.toString().padLeft(2, '0');
      return 'date:${date.year}-${two(date.month)}-${two(date.day)}';
    }

    return 'record:${safe(_recordKey(row))}';
  }

  String _folderTitleFor(
    _TrainerSection section,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return 'Папка';
    final first = rows.first;

    if (section == _TrainerSection.card) return 'Основные данные';

    if (section == _TrainerSection.work) {
      if (first['_trainer_location_folder'] == true) {
        final location = _bridge.asString(
          first['location'] ?? first['venue'] ?? first['address'] ?? first['name'],
        );
        return location.isEmpty ? 'Локация' : location;
      }
      final team = _bridge.teamName(first);
      return team.isEmpty ? 'Команда' : team;
    }

    final dateRaw = _dateFor(section, first);
    if (dateRaw.isNotEmpty) return _friendlyDate(dateRaw);
    return _titleFor(section, first);
  }

  String _folderSubtitleFor(
    _TrainerSection section,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return 'Папка';
    final first = rows.first;
    if (section == _TrainerSection.card) {
      return 'Профиль тренера · документы и заметки';
    }
    if (section == _TrainerSection.work) {
      if (first['_trainer_location_folder'] == true) {
        final team = _bridge.asString(first['team_name']);
        return <String>['Локация', if (team.isNotEmpty) team].join(' · ');
      }
      final location = _bridge.asString(
        first['location'] ?? first['venue'] ?? first['address'],
      );
      return <String>[
        'Команда',
        if (location.isNotEmpty) location,
      ].join(' · ');
    }

    final names = rows
        .map((row) => _titleFor(section, row))
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .take(2)
        .join(' · ');
    final count = rows.length;
    return <String>[
      '$count ${count == 1 ? 'запись' : 'записей'}',
      if (names.isNotEmpty) names,
    ].join(' · ');
  }

  Future<List<Map<String, dynamic>>> _loadSection(_TrainerSection section) async {
    switch (section) {
      case _TrainerSection.work:
        return _loadTrainerWorkFolders();
      case _TrainerSection.schedule:
        return _bridge.loadTrainerSchedule(trainer: _trainer, allTeams: widget.teams);
      case _TrainerSection.attendance:
        return _bridge.loadTrainerAttendance(trainerId: _trainerId, clubId: widget.clubId);
      case _TrainerSection.plans:
        return _bridge.loadTrainerPlans(trainerId: _trainerId, clubId: widget.clubId);
      case _TrainerSection.testing:
        return _bridge.loadTrainerTesting(trainer: _trainer, allTeams: widget.teams, clubId: widget.clubId);
      case _TrainerSection.health:
        return _bridge.loadTrainerHealth(trainerId: _trainerId, clubId: widget.clubId);
      case _TrainerSection.documents:
        return _loadTrainerDocumentsLinked();
      case _TrainerSection.card:
        return <Map<String, dynamic>>[
          <String, dynamic>{
            ..._trainer,
            '_trainer_profile_record': true,
            'title': 'Основные данные',
          },
        ];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTrainerWorkFolders() async {
    final teams = _bridge
        .trainerTeams(_trainer, widget.teams)
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: true);

    final locations = <String, Map<String, dynamic>>{};

    String normalize(String value) => value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[«»"“”„]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    void addLocation(String value, {String teamName = '', String source = ''}) {
      final clean = value.trim();
      if (clean.isEmpty) return;
      final key = normalize(clean);
      if (key.isEmpty) return;
      locations.putIfAbsent(
        key,
        () => <String, dynamic>{
          '_trainer_location_folder': true,
          'name': clean,
          'location': clean,
          if (teamName.trim().isNotEmpty) 'team_name': teamName.trim(),
          if (source.trim().isNotEmpty) 'source': source.trim(),
        },
      );
    }

    for (final team in teams) {
      final teamName = _bridge.teamName(team);
      for (final key in const <String>[
        'location',
        'venue',
        'address',
        'training_base',
        'base',
        'stadium',
      ]) {
        addLocation(
          _bridge.asString(team[key]),
          teamName: teamName,
          source: 'Команда',
        );
      }
    }

    try {
      final schedule = await _bridge.loadTrainerSchedule(
        trainer: _trainer,
        allTeams: widget.teams,
      );
      for (final event in schedule) {
        addLocation(
          _bridge.asString(
            event['location'] ?? event['venue'] ?? event['address'] ?? event['place'],
          ),
          teamName: _bridge.asString(event['team_name']),
          source: 'Расписание',
        );
      }
    } catch (_) {}

    final stored = _bridge.asString(
      _trainer['work_locations'] ?? _trainer['locations'],
    );
    final marker = '#club:${widget.clubId}|';
    for (final raw in stored.split(RegExp(r'[\r\n]+'))) {
      var line = raw.trim();
      if (line.startsWith('#club:') && !line.startsWith(marker)) continue;
      if (line.startsWith(marker)) line = line.substring(marker.length).trim();
      addLocation(line, source: 'Профиль тренера');
    }

    return <Map<String, dynamic>>[...teams, ...locations.values];
  }

  String _titleFor(_TrainerSection section, Map<String, dynamic> row) {
    switch (section) {
      case _TrainerSection.work:
        return _bridge.teamName(row);
      case _TrainerSection.schedule:
        final title = _bridge.asString(row['title'] ?? row['event_title'] ?? row['name']);
        return title.isEmpty ? 'Событие' : title;
      case _TrainerSection.attendance:
        final title = _bridge.asString(row['title'] ?? row['event_title'] ?? row['name'] ?? row['status']);
        return title.isEmpty ? 'Отметка посещаемости' : title;
      case _TrainerSection.plans:
        final title = _bridge.asString(row['theme'] ?? row['title'] ?? row['name']);
        return title.isEmpty ? 'План тренировки' : title;
      case _TrainerSection.testing:
        final category = _bridge.asString(row['category']);
        final stage = _bridge.asString(row['stage']);
        return <String>['Тестирование', if (category.isNotEmpty) category, if (stage.isNotEmpty) stage].join(' · ');
      case _TrainerSection.health:
        final title = _bridge.asString(row['title'] ?? row['name'] ?? row['type']);
        return title.isEmpty ? 'Медицинская запись' : title;
      case _TrainerSection.documents:
        final title = _bridge.asString(row['title'] ?? row['name'] ?? row['file_name'] ?? row['type']);
        return title.isEmpty ? 'Документ' : title;
      case _TrainerSection.card:
        return _bridge.asString(row['title']).isEmpty
            ? 'Основные данные'
            : _bridge.asString(row['title']);
    }
  }

  String _subtitleFor(_TrainerSection section, Map<String, dynamic> row) {
    switch (section) {
      case _TrainerSection.work:
        if (row['_trainer_location_folder'] == true) {
          return <String>[
            'Локация',
            _bridge.asString(row['team_name']),
            _bridge.asString(row['source']),
          ].where((e) => e.isNotEmpty).join(' · ');
        }
        return <String>[
          _bridge.asString(row['link_profile'] ?? row['profile'] ?? row['role']),
          _bridge.asString(row['location'] ?? row['venue'] ?? row['address']),
        ].where((e) => e.isNotEmpty).join(' · ');
      case _TrainerSection.schedule:
        return <String>[
          _bridge.asString(row['team_name']),
          _bridge.asString(row['location'] ?? row['venue']),
        ].where((e) => e.isNotEmpty).join(' · ');
      case _TrainerSection.attendance:
        return <String>[_bridge.asString(row['status'] ?? row['mark']), _bridge.asString(row['comment'] ?? row['note'])].where((e) => e.isNotEmpty).join(' · ');
      case _TrainerSection.plans:
        return <String>[_bridge.asString(row['team_name'] ?? row['_team_name']), _bridge.asString(row['duration'] ?? row['duration_min'])].where((e) => e.isNotEmpty).join(' · ');
      case _TrainerSection.testing:
        return _bridge.asString(row['team_name'] ?? row['title'] ?? row['session_name']);
      case _TrainerSection.health:
        return _bridge.asString(row['comment'] ?? row['notes'] ?? row['record_type']);
      case _TrainerSection.documents:
        return _bridge.asString(row['type'] ?? row['record_type'] ?? row['description']);
      case _TrainerSection.card:
        return <String>[
          if (_role.isNotEmpty) _role,
          _bridge.asString(_trainer['specialization'] ?? _trainer['speciality']),
        ].where((e) => e.isNotEmpty).join(' · ');
    }
  }

  String _dateFor(_TrainerSection section, Map<String, dynamic> row) {
    const keys = <String>['start_at', 'event_date', 'plan_date', 'test_date', 'record_date', 'date', 'created_at', 'uploaded_at'];
    for (final key in keys) {
      final value = _bridge.asString(row[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<WorkspaceEntityProperty> _propertiesFor(_TrainerSection section, Map<String, dynamic> row) {
    final out = <WorkspaceEntityProperty>[];
    void add(String label, dynamic value) {
      final v = _bridge.asString(value);
      if (v.isNotEmpty) out.add(WorkspaceEntityProperty(label, v));
    }
    final date = _dateFor(section, row);
    if (date.isNotEmpty) out.add(WorkspaceEntityProperty('Дата', _friendlyDate(date)));
    switch (section) {
      case _TrainerSection.work:
        if (row['_trainer_location_folder'] == true) {
          add('Локация', row['location'] ?? row['venue'] ?? row['address'] ?? row['name']);
          add('Команда', row['team_name']);
          add('Источник', row['source']);
        } else {
          add('Роль', row['link_profile'] ?? row['profile'] ?? row['role']);
          add('Локация', row['location'] ?? row['venue'] ?? row['address']);
          add('Категория', row['category'] ?? row['age_group']);
        }
        break;
      case _TrainerSection.schedule:
        add('Команда', row['team_name']);
        add('Тип', row['type'] ?? row['event_type']);
        add('Место', row['location'] ?? row['venue'] ?? row['address']);
        break;
      case _TrainerSection.attendance:
        add('Статус', row['status'] ?? row['mark']);
        add('Команда', row['team_name']);
        add('Комментарий', row['comment'] ?? row['note']);
        break;
      case _TrainerSection.plans:
        add('Команда', row['team_name'] ?? row['_team_name']);
        add('Тема', row['theme'] ?? row['title']);
        add('Длительность', row['duration'] ?? row['duration_min']);
        break;
      case _TrainerSection.testing:
        add('Команда', row['team_name']);
        add('Категория', row['category']);
        add('Этап', row['stage']);
        break;
      case _TrainerSection.health:
        add('Тип', row['type'] ?? row['record_type']);
        add('Статус', row['status']);
        add('Комментарий', row['comment'] ?? row['notes']);
        break;
      case _TrainerSection.documents:
        add('Тип', row['type'] ?? row['record_type']);
        add('Автор', row['author'] ?? row['created_by_name']);
        add('Обновлено', row['updated_at'] ?? row['created_at']);
        break;
      case _TrainerSection.card:
        add('Должность', _role);
        add('Специализация', _trainer['specialization'] ?? _trainer['speciality']);
        add('Телефон', _trainer['phone'] ?? _trainer['phone_number']);
        add('Email', _trainer['email']);
        add('Город', _trainer['city'] ?? _trainer['town']);
        add('Опыт', _trainer['experience'] ?? _trainer['work_experience']);
        break;
    }
    return out;
  }

  Future<void> _openRecord(_TrainerSectionFile file, Map<String, dynamic> row) async {
    if (file.section == _TrainerSection.card) {
      await _openChild(_cardDocument());
      return;
    }

    if (file.section == _TrainerSection.work &&
        row['_trainer_location_folder'] != true) {
      await _openChild(
        SportotekaTeamProjectScreen(
          team: Map<String, dynamic>.from(row),
          clubId: widget.clubId,
          currentUserId: widget.currentUserId,
          players: widget.players,
          onRefresh: widget.onRefresh,
        ),
      );
      return;
    }
    final identity = WorkspaceEntityIdentity.resolve(
      clubId: widget.clubId,
      record: row,
      sectionHint: file.section.name,
      fallbackType: 'trainer_${file.section.name}',
      fallbackId: '${_trainerId}_${_recordKey(row)}',
    );
    final legacyKey = 'sportoteka_trainer_${_trainerId}_${file.section.name}_${_recordKey(row)}';
    final doc = WorkspaceEntityRecordDocument(
      ownerTitle: _trainerName,
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
      currentUserId: widget.currentUserId,
      serverParentKey: 'entity:${identity.type}:${identity.id}',
      fileUrl: _findFileUrl(row),
      onRefresh: widget.onRefresh,
      onEdit: file.section == _TrainerSection.documents
          ? () => _editTrainerDocument(row)
          : null,
    );
    await _openChild(doc);
  }

  Future<void> _editTrainerDocument(Map<String, dynamic> record) async {
    String value(List<String> keys) {
      for (final key in keys) {
        final text = _bridge.asString(record[key]);
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final title = TextEditingController(text: value(const <String>['title', 'name']));
    final type = TextEditingController(text: value(const <String>['document_type', 'type']));
    final number = TextEditingController(text: value(const <String>['document_number', 'number']));
    final issuedBy = TextEditingController(text: value(const <String>['issued_by']));
    final issueDate = TextEditingController(text: value(const <String>['issue_date', 'date']));
    final validUntil = TextEditingController(text: value(const <String>['valid_until']));
    final note = TextEditingController(text: value(const <String>['note', 'comment', 'description']));

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Документ тренера', style: AppTypography.sectionTitle(color: _text)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 9),
                TextField(controller: type, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Тип документа')),
                const SizedBox(height: 9),
                TextField(controller: number, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Номер')),
                const SizedBox(height: 9),
                TextField(controller: issuedBy, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Кем выдан')),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: TextField(controller: issueDate, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Дата YYYY-MM-DD'))),
                  const SizedBox(width: 9),
                  Expanded(child: TextField(controller: validUntil, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Действует до'))),
                ]),
                const SizedBox(height: 9),
                TextField(controller: note, minLines: 3, maxLines: 6, style: AppTypography.formText(color: _text), decoration: const InputDecoration(labelText: 'Заметка')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('Отмена', style: AppTypography.action(color: _muted))),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _green, elevation: 0),
            child: Text('Сохранить', style: AppTypography.actionStrong(color: Colors.white)),
          ),
        ],
      ),
    );

    try {
      if (saved == true) {
        await _bridge.updateTrainerDocument(
          trainerId: _trainerId,
          clubId: widget.clubId,
          record: record,
          title: title.text,
          documentType: type.text,
          note: note.text,
          documentNumber: number.text,
          issuedBy: issuedBy.text,
          issueDate: issueDate.text,
          validUntil: validUntil.text,
        );
        await widget.onRefresh?.call();
      }
    } finally {
      title.dispose(); type.dispose(); number.dispose(); issuedBy.dispose(); issueDate.dispose(); validUntil.dispose(); note.dispose();
    }
  }

  Future<void> _editTrainer() async {
    final position = TextEditingController(
      text: _bridge.asString(
        _trainer['position'] ?? _trainer['role_title'],
      ),
    );
    final specialization = TextEditingController(
      text: _bridge.asString(_trainer['specialization']),
    );
    final city = TextEditingController(
      text: _bridge.asString(_trainer['city']),
    );

    final marker = '#club:${widget.clubId}|';
    final storedLocations = _bridge.asString(
      _trainer['work_locations'] ?? _trainer['locations'],
    );
    final manualValues = <String>[];
    for (final raw in storedLocations.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (!line.startsWith(marker)) continue;
      final value = line.substring(marker.length).trim();
      if (value.isNotEmpty && !manualValues.contains(value)) {
        manualValues.add(value);
      }
    }

    final locations = TextEditingController(
      text: manualValues.join('\n'),
    );

    final schedule = await _bridge.loadTrainerSchedule(
      trainer: _trainer,
      allTeams: widget.teams,
    );
    if (!mounted) {
      position.dispose();
      specialization.dispose();
      city.dispose();
      locations.dispose();
      return;
    }

    String normalize(String value) => value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[«»"“”„]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final automatic = <String, String>{};

    for (final team in _bridge.trainerTeams(_trainer, widget.teams)) {
      final teamName = _bridge.teamName(team);
      for (final key in const <String>[
        'location',
        'venue',
        'address',
        'training_base',
        'base',
        'stadium',
      ]) {
        final value = _bridge.asString(team[key]);
        if (value.isEmpty) continue;
        final label = teamName.isEmpty ? value : '$teamName — $value';
        automatic.putIfAbsent(normalize(label), () => label);
      }
    }

    for (final event in schedule) {
      final teamName = _bridge.asString(event['team_name']);
      final value = _bridge.asString(
        event['location'] ??
            event['venue'] ??
            event['address'] ??
            event['place'],
      );
      if (value.isEmpty) continue;
      final label = teamName.isEmpty ? value : '$teamName — $value';
      automatic.putIfAbsent(normalize(label), () => label);
    }

    final automaticText = automatic.values.isEmpty
        ? 'Автоматические локации пока не найдены'
        : automatic.values.join('\n');

    final birthday = TextEditingController(
      text: _bridge.asString(
        _trainer['birthday'] ?? _trainer['birth_date'],
      ),
    );
    final experience = TextEditingController(
      text: _bridge.asString(
        _trainer['experience'] ?? _trainer['work_experience'],
      ),
    );
    final phone = TextEditingController(
      text: _bridge.asString(
        _trainer['phone'] ?? _trainer['phone_number'],
      ),
    );
    final bio = TextEditingController(
      text: _bridge.asString(
        _trainer['bio'] ?? _trainer['description'],
      ),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Редактировать тренера',
          style: AppTypography.sectionTitle(color: _text),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(position, 'Должность'),
                _field(specialization, 'Специализация'),
                _field(city, 'Город'),
                TextFormField(
                  initialValue: automaticText,
                  readOnly: true,
                  minLines: 2,
                  maxLines: 5,
                  style: AppTypography.formText(color: _muted),
                  decoration: const InputDecoration(
                    labelText: 'Локации автоматически из команд и календаря',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locations,
                  minLines: 2,
                  maxLines: 5,
                  style: AppTypography.formText(color: _text),
                  decoration: const InputDecoration(
                    labelText: 'Ручная корректировка локаций',
                    hintText:
                        'Каждая итоговая локация с новой строки. Если пусто — используются автоматические.',
                  ),
                ),
                const SizedBox(height: 10),
                _field(birthday, 'Дата рождения'),
                _field(experience, 'Опыт'),
                _field(phone, 'Телефон'),
                TextField(
                  controller: bio,
                  maxLines: 4,
                  style: AppTypography.formText(color: _text),
                  decoration: const InputDecoration(
                    labelText: 'О тренере',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Отмена',
              style: AppTypography.action(color: _muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              final keep = storedLocations
                  .split(RegExp(r'[\r\n]+'))
                  .map((value) => value.trim())
                  .where(
                    (value) =>
                        value.isNotEmpty && !value.startsWith(marker),
                  )
                  .toList();

              final seen = <String>{};
              for (final raw in locations.text.split(RegExp(r'[\r\n;]+'))) {
                final value = raw.trim();
                if (value.isEmpty) continue;
                final key = normalize(value);
                if (!seen.add(key)) continue;
                keep.add('$marker$value');
              }

              final ok = await _bridge.saveTrainerProfile(
                trainer: _trainer,
                fields: <String, String>{
                  'position': position.text.trim(),
                  'specialization': specialization.text.trim(),
                  'city': city.text.trim(),
                  'work_locations': keep.join('\n'),
                  'birthday': birthday.text.trim(),
                  'experience': experience.text.trim(),
                  'phone': phone.text.trim(),
                  'bio': bio.text.trim(),
                },
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext, ok);
            },
            child: Text(
              'Сохранить',
              style: AppTypography.actionStrong(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    position.dispose();
    specialization.dispose();
    city.dispose();
    locations.dispose();
    birthday.dispose();
    experience.dispose();
    phone.dispose();
    bio.dispose();

    if (saved == true) {
      await _refreshProfile();
      await widget.onRefresh?.call();
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: controller, style: AppTypography.formText(color: _text), decoration: InputDecoration(labelText: label)),
      );

  String _recordKey(Map<String, dynamic> row) {
    for (final key in const <String>['id', 'event_id', 'plan_id', 'session_id', 'record_id', 'date', 'created_at']) {
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
                  const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.trainers, size: 38),
                  const SizedBox(width: 10),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_trainerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.screenTitle(color: _text)),
                    Text(_role.isEmpty ? 'Тренер' : _role, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.secondary(color: _muted)),
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
                          const _TrainerBrandDots(),
                          const Spacer(),
                          Text('${_sections.length} разделов', style: AppTypography.caption(color: _trainerProjectMuted)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(mobile ? 8 : 14, 0, mobile ? 8 : 14, 20),
                        itemCount: _sections.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 54, color: _trainerProjectLine),
                        itemBuilder: (_, index) {
                          final file = _sections[index];
                          return _TrainerFolderTile(file: file, mobile: mobile, onTap: () => _open(file));
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
                child: Row(children: [Text('${_sections.length} разделов', style: AppTypography.caption(color: _trainerProjectMuted)), const Spacer(), Text('SPORTOTEKA OS · TRAINER', style: AppTypography.menuGroup(color: _muted))]),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _TrainerAutoFolder {
  const _TrainerAutoFolder({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.serverParentKey,
    required this.rows,
  });

  final String key;
  final String title;
  final String subtitle;
  final String serverParentKey;
  final List<Map<String, dynamic>> rows;
}

class _TrainerSectionFolderBrowser extends StatefulWidget {
  const _TrainerSectionFolderBrowser({
    required this.ownerTitle,
    required this.sectionTitle,
    required this.sectionIcon,
    required this.trainerId,
    required this.clubId,
    required this.currentUserId,
    required this.sectionKey,
    required this.loadRows,
    required this.folderKeyFor,
    required this.folderTitleFor,
    required this.folderSubtitleFor,
    required this.onOpenFolder,
    required this.onOpenSectionDocuments,
  });

  final String ownerTitle;
  final String sectionTitle;
  final SportotekaWorkspaceIconKind sectionIcon;
  final int trainerId;
  final int clubId;
  final int currentUserId;
  final String sectionKey;
  final Future<List<Map<String, dynamic>>> Function() loadRows;
  final String Function(Map<String, dynamic> row) folderKeyFor;
  final String Function(List<Map<String, dynamic>> rows) folderTitleFor;
  final String Function(List<Map<String, dynamic>> rows) folderSubtitleFor;
  final Future<void> Function(_TrainerAutoFolder folder) onOpenFolder;
  final Future<void> Function() onOpenSectionDocuments;

  @override
  State<_TrainerSectionFolderBrowser> createState() =>
      _TrainerSectionFolderBrowserState();
}

class _TrainerSectionFolderBrowserState
    extends State<_TrainerSectionFolderBrowser> {
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  static const _green = Color(0xFF0B8F55);

  bool _loading = true;
  String _error = '';
  List<_TrainerAutoFolder> _folders = const <_TrainerAutoFolder>[];

  String get _sectionParentKey =>
      'trainer:${widget.trainerId}:${widget.sectionKey}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _safeKey(String value) {
    final clean = value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-z0-9а-я:_-]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return clean.isEmpty ? 'folder' : clean;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final rows = await widget.loadRows();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final source in rows) {
        final row = Map<String, dynamic>.from(source);
        final rawKey = widget.folderKeyFor(row).trim();
        final key = rawKey.isEmpty ? 'folder' : rawKey;
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
      }

      final folders = <_TrainerAutoFolder>[];
      for (final entry in grouped.entries) {
        final groupRows = entry.value;
        final safe = _safeKey(entry.key);
        folders.add(
          _TrainerAutoFolder(
            key: safe,
            title: widget.folderTitleFor(groupRows),
            subtitle: widget.folderSubtitleFor(groupRows),
            serverParentKey:
                'local-folder:trainer-auto:${widget.trainerId}:${widget.sectionKey}:$safe',
            rows: groupRows,
          ),
        );
      }

      final mergedFolders = await _mergePersistedFolders(folders);
      mergedFolders.sort((a, b) {
        final ad = a.key.startsWith('date:');
        final bd = b.key.startsWith('date:');
        if (ad && bd) return b.key.compareTo(a.key);
        if (ad != bd) return ad ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      // Данные раздела уже загружены — показываем папки сразу.
      // Серверная синхронизация не должна держать экран на спиннере.
      if (!mounted) return;
      setState(() {
        _folders = mergedFolders;
        _loading = false;
      });
      unawaited(_syncFolders(mergedFolders));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<List<_TrainerAutoFolder>> _mergePersistedFolders(
    List<_TrainerAutoFolder> current,
  ) async {
    if (widget.clubId <= 0 || widget.trainerId <= 0) return current;
    try {
      final storage = WorkspaceServerStorage(
        clubId: widget.clubId,
        userId: widget.currentUserId,
      );
      final snapshot = await storage.load();
      final persisted = <String, WorkspaceFinderNode>{
        for (final node in snapshot.nodes)
          if (node.parentId == _sectionParentKey &&
              node.payload?['_trainer_auto_folder'] == true)
            node.id: node,
      };

      final out = <_TrainerAutoFolder>[];
      final known = <String>{};
      for (final folder in current) {
        known.add(folder.serverParentKey);
        final stored = persisted[folder.serverParentKey];
        final hasCustomTitle =
            stored?.payload?['_trainer_custom_title'] == true &&
            (stored?.title.trim().isNotEmpty ?? false);
        out.add(
          _TrainerAutoFolder(
            key: folder.key,
            title: hasCustomTitle ? stored!.title.trim() : folder.title,
            subtitle: folder.subtitle,
            serverParentKey: folder.serverParentKey,
            rows: folder.rows,
          ),
        );
      }

      // Папки, в которые пользователь уже добавил документы, не исчезают,
      // даже если исходная запись временно не пришла с сервера.
      for (final node in persisted.values) {
        if (known.contains(node.id)) continue;
        final storedKey = '${node.payload?['folder_key'] ?? node.id}'.trim();
        out.add(
          _TrainerAutoFolder(
            key: _safeKey(storedKey),
            title: node.title,
            subtitle: node.subtitle.trim().isEmpty
                ? 'Сохранённая папка тренера'
                : node.subtitle,
            serverParentKey: node.id,
            rows: const <Map<String, dynamic>>[],
          ),
        );
      }
      return out;
    } catch (_) {
      return current;
    }
  }

  Future<void> _syncFolders(List<_TrainerAutoFolder> folders) async {
    if (widget.clubId <= 0 || widget.trainerId <= 0) return;
    try {
      final storage = WorkspaceServerStorage(
        clubId: widget.clubId,
        userId: widget.currentUserId,
      );
      final snapshot = await storage.load();
      final existing = <String, WorkspaceFinderNode>{
        for (final node in snapshot.nodes)
          if (node.parentId == _sectionParentKey &&
              node.payload?['_trainer_auto_folder'] == true)
            node.id: node,
      };

      for (final folder in folders) {
        final old = existing[folder.serverParentKey];
        final oldPayload = old?.payload ?? const <String, dynamic>{};
        final payload = <String, dynamic>{
          ...oldPayload,
          '_trainer_auto_folder': true,
          'trainer_id': widget.trainerId,
          'section_key': widget.sectionKey,
          'folder_key': folder.key,
          'record_count': folder.rows.length,
        };
        final node = WorkspaceFinderNode(
          id: folder.serverParentKey,
          title: folder.title,
          subtitle: folder.subtitle,
          kind: WorkspaceFinderNodeKind.folder,
          parentId: _sectionParentKey,
          payload: payload,
          createdAt: old?.createdAt,
          updatedAt: DateTime.now(),
        );

        if (old == null) {
          await storage.createNode(node);
          continue;
        }

        final changed =
            old.title != node.title ||
            old.subtitle != node.subtitle ||
            old.parentId != node.parentId ||
            old.payload?['record_count'] != folder.rows.length ||
            old.payload?['folder_key'] != folder.key ||
            old.payload?['section_key'] != widget.sectionKey;
        if (changed) {
          await storage.updateNode(node);
        }
      }
    } catch (_) {
      // Автопапки остаются доступны в UI даже при временной недоступности sync.
    }
  }

  Future<void> _renameFolder(_TrainerAutoFolder folder) async {
    final controller = TextEditingController(text: folder.title);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать папку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Название папки',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (text) {
            final clean = text.trim();
            if (clean.isNotEmpty) Navigator.of(dialogContext).pop(clean);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final clean = controller.text.trim();
              if (clean.isNotEmpty) Navigator.of(dialogContext).pop(clean);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = value?.trim() ?? '';
    if (clean.isEmpty || clean == folder.title) return;

    final renamed = _TrainerAutoFolder(
      key: folder.key,
      title: clean,
      subtitle: folder.subtitle,
      serverParentKey: folder.serverParentKey,
      rows: folder.rows,
    );
    if (mounted) {
      setState(() {
        _folders = _folders
            .map((item) => item.serverParentKey == folder.serverParentKey
                ? renamed
                : item)
            .toList(growable: false);
      });
    }

    try {
      final storage = WorkspaceServerStorage(
        clubId: widget.clubId,
        userId: widget.currentUserId,
      );
      final snapshot = await storage.load();
      WorkspaceFinderNode? existing;
      for (final node in snapshot.nodes) {
        if (node.id == folder.serverParentKey) {
          existing = node;
          break;
        }
      }
      final payload = <String, dynamic>{
        ...?existing?.payload,
        '_trainer_auto_folder': true,
        '_trainer_custom_title': true,
        'trainer_id': widget.trainerId,
        'section_key': widget.sectionKey,
        'folder_key': folder.key,
        'record_count': folder.rows.length,
      };
      final node = WorkspaceFinderNode(
        id: folder.serverParentKey,
        title: clean,
        subtitle: folder.subtitle,
        kind: WorkspaceFinderNodeKind.folder,
        parentId: _sectionParentKey,
        payload: payload,
        createdAt: existing?.createdAt,
        updatedAt: DateTime.now(),
      );
      if (existing == null) {
        await storage.createNode(node);
      } else {
        await storage.updateNode(node);
      }
    } catch (_) {
      // Локально название уже изменено; повторная загрузка попробует синхронизацию снова.
    }
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
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const SportotekaWorkspaceIcon(
                        kind: SportotekaWorkspaceIconKind.back,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const _TrainerFolderIcon(size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sectionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.screenTitle(color: _text),
                          ),
                          Text(
                            widget.ownerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.secondary(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (!mobile)
                      TextButton.icon(
                        onPressed: widget.onOpenSectionDocuments,
                        icon: const Icon(Icons.note_add_outlined, size: 17),
                        label: Text(
                          'Документ',
                          style: AppTypography.actionStrong(color: _green),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _line),
              if (mobile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onOpenSectionDocuments,
                      icon: const Icon(Icons.note_add_outlined, size: 17),
                      label: Text(
                        'Добавить документ',
                        style: AppTypography.actionStrong(color: _green),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _error.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Не удалось загрузить данные раздела',
                                    style: AppTypography.itemTitle(color: _text),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _error,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.caption(color: _muted),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _folders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _TrainerFolderIcon(size: 52),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Автоматических папок пока нет.',
                                        style: AppTypography.secondary(color: _muted),
                                      ),
                                      const SizedBox(height: 10),
                                      FilledButton.icon(
                                        onPressed: widget.onOpenSectionDocuments,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _green,
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.note_add_outlined, size: 17),
                                        label: Text(
                                          'Создать документ',
                                          style: AppTypography.actionStrong(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  mobile ? 8 : 14,
                                  8,
                                  mobile ? 8 : 14,
                                  20,
                                ),
                                itemCount: _folders.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, indent: 54, color: _line),
                                itemBuilder: (_, index) {
                                  final folder = _folders[index];
                                  return _TrainerAutoFolderTile(
                                    folder: folder,
                                    onTap: () => widget.onOpenFolder(folder),
                                    onRename: () => _renameFolder(folder),
                                  );
                                },
                              ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_folders.length} папок',
                      style: AppTypography.caption(color: _muted),
                    ),
                    const Spacer(),
                    Text(
                      'SPORTOTEKA OS · FOLDER',
                      style: AppTypography.menuGroup(color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrainerAutoFolderTile extends StatelessWidget {
  const _TrainerAutoFolderTile({
    required this.folder,
    required this.onTap,
    required this.onRename,
  });

  final _TrainerAutoFolder folder;
  final VoidCallback onTap;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              const _TrainerFolderIcon(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.itemTitle(color: _trainerProjectText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folder.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(color: _trainerProjectMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Действия с папкой',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: _trainerProjectMuted,
                ),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Переименовать'),
                      ],
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: _trainerProjectMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


const _trainerProjectGreen = Color(0xFF0B8F55);
const _trainerProjectText = Color(0xFF101814);
const _trainerProjectMuted = Color(0xFF758079);
const _trainerProjectLine = Color(0xFFE7EAE7);

class _TrainerFolderTile extends StatelessWidget {
  const _TrainerFolderTile({required this.file, required this.mobile, required this.onTap});
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
              const _TrainerFolderIcon(size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(file.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _trainerProjectText))),
                        const SizedBox(width: 6),
                        const _TrainerBrandDots(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(file.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _trainerProjectMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 17, color: _trainerProjectMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerFolderIcon extends StatelessWidget {
  const _TrainerFolderIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SportotekaWorkspaceFolderIcon(
        size: size,
        color: const Color(0xFF8D9490),
        fillColor: const Color(0xFFF2F3F2),
        accentColor: _trainerProjectGreen,
        showBrandDots: true,
      );
}

class _TrainerBrandDots extends StatelessWidget {
  const _TrainerBrandDots();

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

enum _TrainerSection { card, work, schedule, attendance, plans, testing, health, documents }

class _TrainerSectionFile {
  const _TrainerSectionFile(this.section, this.title, this.subtitle, this.icon);
  final _TrainerSection section;
  final String title;
  final String subtitle;
  final SportotekaWorkspaceIconKind icon;
}
