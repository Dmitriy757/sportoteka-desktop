import 'package:flutter/material.dart';

enum WorkspaceFinderNodeKind {
  folder,
  team,
  player,
  trainer,
  match,
  training,
  plan,
  tracker,
  testing,
  calendar,
  document,
  video,
  report,
  chat,
  medical,
  parent,
  shortcut,
  note,
}

enum WorkspaceFinderViewMode { grid, list }

class WorkspaceFinderNode {
  const WorkspaceFinderNode({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle = '',
    this.moduleKey,
    this.payload,
    this.parentId,
    this.isSystem = false,
    this.isFavorite = false,
    this.isShortcut = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final WorkspaceFinderNodeKind kind;
  final String? moduleKey;
  final Map<String, dynamic>? payload;
  final String? parentId;
  final bool isSystem;
  final bool isFavorite;
  final bool isShortcut;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFolder => kind == WorkspaceFinderNodeKind.folder;

  WorkspaceFinderNode copyWith({
    String? id,
    String? title,
    String? subtitle,
    WorkspaceFinderNodeKind? kind,
    String? moduleKey,
    Map<String, dynamic>? payload,
    String? parentId,
    bool? isSystem,
    bool? isFavorite,
    bool? isShortcut,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkspaceFinderNode(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      kind: kind ?? this.kind,
      moduleKey: moduleKey ?? this.moduleKey,
      payload: payload ?? this.payload,
      parentId: parentId ?? this.parentId,
      isSystem: isSystem ?? this.isSystem,
      isFavorite: isFavorite ?? this.isFavorite,
      isShortcut: isShortcut ?? this.isShortcut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WorkspaceFinderModuleDefinition {
  const WorkspaceFinderModuleDefinition({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
    this.requiresTeam = false,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final WorkspaceFinderNodeKind kind;
  final bool requiresTeam;
}

const List<WorkspaceFinderModuleDefinition> kWorkspaceFinderModules = <WorkspaceFinderModuleDefinition>[
  WorkspaceFinderModuleDefinition(
    key: 'teams',
    title: 'Команды',
    subtitle: 'Составы, тренеры и рабочие данные',
    icon: Icons.account_tree_rounded,
    kind: WorkspaceFinderNodeKind.team,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'players',
    title: 'Игроки',
    subtitle: 'Карточки, дневник, активность и документы',
    icon: Icons.groups_2_rounded,
    kind: WorkspaceFinderNodeKind.player,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'trainers',
    title: 'Тренеры',
    subtitle: 'Профили, назначения и документы',
    icon: Icons.badge_rounded,
    kind: WorkspaceFinderNodeKind.trainer,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'matches',
    title: 'Матчи',
    subtitle: 'Игры, видео, аналитика и отчёты',
    icon: Icons.sports_soccer_rounded,
    kind: WorkspaceFinderNodeKind.match,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'trainings',
    title: 'Тренировки',
    subtitle: 'Календарь, посещаемость и активность',
    icon: Icons.fitness_center_rounded,
    kind: WorkspaceFinderNodeKind.training,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'plans',
    title: 'Планы-конспекты',
    subtitle: 'Методические материалы и упражнения',
    icon: Icons.folder_copy_rounded,
    kind: WorkspaceFinderNodeKind.plan,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'tracker',
    title: 'Tracker',
    subtitle: 'GPS, нагрузка, карты и отчёты',
    icon: Icons.sensors_rounded,
    kind: WorkspaceFinderNodeKind.tracker,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'testing',
    title: 'Тестирование',
    subtitle: 'Физика, техника, тактика и история',
    icon: Icons.science_rounded,
    kind: WorkspaceFinderNodeKind.testing,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'calendar',
    title: 'Календарь',
    subtitle: 'События клуба и команды',
    icon: Icons.calendar_month_rounded,
    kind: WorkspaceFinderNodeKind.calendar,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'documents',
    title: 'Документы',
    subtitle: 'Файлы клуба, игроков и тренеров',
    icon: Icons.description_rounded,
    kind: WorkspaceFinderNodeKind.document,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'video',
    title: 'Видео',
    subtitle: 'Анализ матчей и видеоуроки',
    icon: Icons.video_library_rounded,
    kind: WorkspaceFinderNodeKind.video,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'reports',
    title: 'Отчёты',
    subtitle: 'Tracker, тесты, посещаемость и PDF',
    icon: Icons.analytics_rounded,
    kind: WorkspaceFinderNodeKind.report,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'medical',
    title: 'Медкарта',
    subtitle: 'Состояние и документы игроков',
    icon: Icons.medical_information_rounded,
    kind: WorkspaceFinderNodeKind.medical,
    requiresTeam: true,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'chat',
    title: 'Чаты',
    subtitle: 'Коммуникация клуба и команды',
    icon: Icons.forum_rounded,
    kind: WorkspaceFinderNodeKind.chat,
  ),
  WorkspaceFinderModuleDefinition(
    key: 'parents',
    title: 'Родители',
    subtitle: 'Доступы, связь и уведомления',
    icon: Icons.family_restroom_rounded,
    kind: WorkspaceFinderNodeKind.parent,
    requiresTeam: true,
  ),
];

IconData workspaceFinderIconForKind(WorkspaceFinderNodeKind kind) {
  switch (kind) {
    case WorkspaceFinderNodeKind.folder:
      return Icons.folder_rounded;
    case WorkspaceFinderNodeKind.team:
      return Icons.account_tree_rounded;
    case WorkspaceFinderNodeKind.player:
      return Icons.person_rounded;
    case WorkspaceFinderNodeKind.trainer:
      return Icons.badge_rounded;
    case WorkspaceFinderNodeKind.match:
      return Icons.sports_soccer_rounded;
    case WorkspaceFinderNodeKind.training:
      return Icons.fitness_center_rounded;
    case WorkspaceFinderNodeKind.plan:
      return Icons.folder_copy_rounded;
    case WorkspaceFinderNodeKind.tracker:
      return Icons.sensors_rounded;
    case WorkspaceFinderNodeKind.testing:
      return Icons.science_rounded;
    case WorkspaceFinderNodeKind.calendar:
      return Icons.calendar_month_rounded;
    case WorkspaceFinderNodeKind.document:
      return Icons.description_rounded;
    case WorkspaceFinderNodeKind.video:
      return Icons.video_library_rounded;
    case WorkspaceFinderNodeKind.report:
      return Icons.analytics_rounded;
    case WorkspaceFinderNodeKind.chat:
      return Icons.forum_rounded;
    case WorkspaceFinderNodeKind.medical:
      return Icons.medical_information_rounded;
    case WorkspaceFinderNodeKind.parent:
      return Icons.family_restroom_rounded;
    case WorkspaceFinderNodeKind.shortcut:
      return Icons.shortcut_rounded;
    case WorkspaceFinderNodeKind.note:
      return Icons.note_alt_rounded;
  }
}
