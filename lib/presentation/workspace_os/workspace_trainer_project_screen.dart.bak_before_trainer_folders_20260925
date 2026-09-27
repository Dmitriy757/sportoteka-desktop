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
    final child = file.section == _TrainerSection.card ? _cardDocument() : _browser(file);
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
      emptyText: 'В этом разделе пока нет записей.',
    );
  }

  Future<List<Map<String, dynamic>>> _loadSection(_TrainerSection section) async {
    switch (section) {
      case _TrainerSection.work:
        return _bridge.trainerTeams(_trainer, widget.teams);
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
        return <Map<String, dynamic>>[];
    }
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
        return 'Карточка тренера';
    }
  }

  String _subtitleFor(_TrainerSection section, Map<String, dynamic> row) {
    switch (section) {
      case _TrainerSection.work:
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
        return '';
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
        add('Роль', row['link_profile'] ?? row['profile'] ?? row['role']);
        add('Локация', row['location'] ?? row['venue'] ?? row['address']);
        add('Категория', row['category'] ?? row['age_group']);
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
        break;
    }
    return out;
  }

  Future<void> _openRecord(_TrainerSectionFile file, Map<String, dynamic> row) async {
    if (file.section == _TrainerSection.work) {
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
                color: index == 0 || index == 4 || index == 7 ? const Color(0xFF0B8F55) : const Color(0xFFC7D2CC),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
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
