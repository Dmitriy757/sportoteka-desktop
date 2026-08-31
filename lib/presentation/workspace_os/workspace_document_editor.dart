import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_live_blocks.dart';

/// Самописный редактор заметок Sportoteka OS.
///
/// Редактор не зависит от стороннего rich-text пакета: форматирование хранится
/// в простом переносимом тексте, а контекст игрока, тренера или команды
/// отображается отдельно и не смешивается с содержимым документа.
class WorkspaceDocumentEditor extends StatefulWidget {
  const WorkspaceDocumentEditor({
    super.key,
    required this.initialTitle,
    this.initialBody = '',
    this.readOnly = false,
    this.titleReadOnly = false,
    this.onSave,
    this.contextLabel = 'Рабочая заметка',
    this.contextName = '',
    this.documentType = 'Заметка',
    this.autoSave = true,
    this.showTemplates = true,
    this.onClose,
    this.liveBlocksKey,
  });

  final String initialTitle;
  final String initialBody;
  final bool readOnly;
  final bool titleReadOnly;
  final Future<void> Function(String title, String body)? onSave;
  final String contextLabel;
  final String contextName;
  final String documentType;
  final bool autoSave;
  final bool showTemplates;
  final VoidCallback? onClose;
  final String? liveBlocksKey;

  @override
  State<WorkspaceDocumentEditor> createState() =>
      _WorkspaceDocumentEditorState();
}

class _WorkspaceDocumentEditorState extends State<WorkspaceDocumentEditor> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE6EAE7);
  static const _surface = Colors.white;

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final FocusNode _bodyFocus = FocusNode();

  Timer? _autoSaveTimer;
  bool _saving = false;
  bool _saveQueued = false;
  bool _saveError = false;
  int _revision = 0;
  int _savedRevision = 0;

  List<WorkspaceLiveBlock> _liveBlocks = <WorkspaceLiveBlock>[];
  bool _liveBlocksLoading = false;
  bool _slashLiveBlockPending = false;

  // На широком экране вставка живого блока открывается прямо внутри
  // текущего окна редактора — отдельной правой панелью, а не modal/bottom sheet.
  WorkspaceLiveBlockType? _sidePickerType;

  bool get _dirty => _revision != _savedRevision;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _titleController.addListener(_handleEdit);
    _bodyController.addListener(_handleEdit);
    _loadLiveBlocks();
  }

  @override
  void didUpdateWidget(covariant WorkspaceDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final blocksKeyChanged = _liveBlocksKeyFor(oldWidget) != _effectiveLiveBlocksKey;
    if (blocksKeyChanged) _loadLiveBlocks();
    if (_dirty || _saving) return;
    final titleChanged = oldWidget.initialTitle != widget.initialTitle;
    final bodyChanged = oldWidget.initialBody != widget.initialBody;
    if (!titleChanged && !bodyChanged) return;

    _titleController.removeListener(_handleEdit);
    _bodyController.removeListener(_handleEdit);
    if (titleChanged) _titleController.text = widget.initialTitle;
    if (bodyChanged) _bodyController.text = widget.initialBody;
    _titleController.addListener(_handleEdit);
    _bodyController.addListener(_handleEdit);
    _revision = 0;
    _savedRevision = 0;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_handleEdit);
    _bodyController.removeListener(_handleEdit);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  String _liveBlocksKeyFor(WorkspaceDocumentEditor source) {
    final explicit = source.liveBlocksKey?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final seed = '${source.contextLabel}|${source.contextName}|${source.documentType}|${source.initialTitle}';
    var hash = 0x811C9DC5;
    for (final code in seed.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'workspace_doc_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  String get _effectiveLiveBlocksKey => _liveBlocksKeyFor(widget);

  Future<void> _loadLiveBlocks() async {
    if (mounted) setState(() => _liveBlocksLoading = true);
    try {
      final blocks = await WorkspaceLiveBlocksRepository(documentKey: _effectiveLiveBlocksKey).load();
      if (!mounted) return;
      setState(() {
        _liveBlocks = blocks;
        _liveBlocksLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _liveBlocksLoading = false);
    }
  }

  Future<void> _persistLiveBlocks() async {
    try {
      await WorkspaceLiveBlocksRepository(documentKey: _effectiveLiveBlocksKey).save(_liveBlocks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Изменение сохранено локально, но пока не синхронизировано с сервером')),
      );
    }
  }

  void _checkSlashLiveBlockCommand() {
    if (widget.readOnly || _slashLiveBlockPending) return;
    final lower = _bodyController.text.toLowerCase();
    for (final reportCommand in const <String>['/отчет', '/отчёт', '/report']) {
      if (lower.endsWith(reportCommand)) {
        _slashLiveBlockPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final current = _bodyController.text;
          if (current.toLowerCase().endsWith(reportCommand)) {
            final next = current.substring(0, current.length - reportCommand.length);
            _bodyController.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
          }
          await _buildSmartReport();
          if (mounted) _slashLiveBlockPending = false;
        });
        return;
      }
    }
    const commands = <String, WorkspaceLiveBlockType>{
      '/план': WorkspaceLiveBlockType.plan,
      '/plan': WorkspaceLiveBlockType.plan,
      '/матч': WorkspaceLiveBlockType.match,
      '/match': WorkspaceLiveBlockType.match,
      '/тренировка': WorkspaceLiveBlockType.training,
      '/training': WorkspaceLiveBlockType.training,
      '/игрок': WorkspaceLiveBlockType.player,
      '/player': WorkspaceLiveBlockType.player,
      '/tracker': WorkspaceLiveBlockType.tracker,
      '/трекер': WorkspaceLiveBlockType.tracker,
      '/тест': WorkspaceLiveBlockType.testing,
      '/testing': WorkspaceLiveBlockType.testing,
      '/видео': WorkspaceLiveBlockType.video,
      '/video': WorkspaceLiveBlockType.video,
      '/документ': WorkspaceLiveBlockType.document,
      '/document': WorkspaceLiveBlockType.document,
    };
    String command = '';
    WorkspaceLiveBlockType? type;
    for (final entry in commands.entries) {
      if (lower.endsWith(entry.key)) { command = entry.key; type = entry.value; break; }
    }
    if (command.isEmpty || type == null) return;
    _slashLiveBlockPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final current = _bodyController.text;
      if (current.toLowerCase().endsWith(command)) {
        final next = current.substring(0, current.length - command.length);
        _bodyController.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
      }
      await _insertLiveBlock(type!);
      if (mounted) _slashLiveBlockPending = false;
    });
  }

  Future<void> _insertLiveBlock(WorkspaceLiveBlockType type) async {
    if (widget.readOnly) return;

    final media = MediaQuery.maybeOf(context);
    final width = media?.size.width ?? 0;
    final shortestSide = media == null
        ? 0.0
        : (media.size.width < media.size.height ? media.size.width : media.size.height);

    // На desktop/tablet всегда открываем picker внутри текущего окна редактора.
    // Это не зависит от фактической ширины самого OS-окна.
    if (width >= 600 || shortestSide >= 600) {
      if (!mounted) return;
      setState(() => _sidePickerType = type);
      return;
    }

    final block = await showWorkspaceLiveBlockPicker(context, type);
    if (block == null || !mounted) return;
    await _acceptLiveBlock(block);
  }

  Future<void> _acceptLiveBlock(WorkspaceLiveBlock block) async {
    final duplicate = _liveBlocks.any((item) =>
        item.type == block.type &&
        ((item.entityId > 0 && block.entityId > 0 && item.entityId == block.entityId) ||
            (item.entityKey.isNotEmpty && item.entityKey == block.entityKey)));
    if (duplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Этот объект уже вставлен в документ')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _liveBlocks = <WorkspaceLiveBlock>[..._liveBlocks, block];
      _sidePickerType = null;
    });
    await _persistLiveBlocks();
  }

  Future<void> _insertPlanBlock() => _insertLiveBlock(WorkspaceLiveBlockType.plan);

  Future<void> _buildSmartReport() async {
    if (widget.readOnly) return;
    if (_liveBlocks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сначала вставьте Матч, План, Игрока, Tracker или другой живой блок')),
        );
      }
      return;
    }

    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${two(now.day)}.${two(now.month)}.${now.year}';
    final lines = <String>[
      '# ОТЧЁТ SPORTOTEKA',
      '',
      'Дата: $date',
      if (widget.contextName.trim().isNotEmpty) 'Контекст: ${widget.contextName.trim()}',
      '',
      '## Использованные материалы',
      '',
    ];

    for (final block in _liveBlocks) {
      lines.addAll(_reportLinesForBlock(block));
    }

    lines.addAll(<String>[
      '## Ключевые наблюдения',
      '',
      '• ',
      '• ',
      '• ',
      '',
      '## Выводы и следующие действия',
      '',
      '1. ',
      '2. ',
      '3. ',
    ]);

    final generated = lines.join('\n');
    final current = _bodyController.text.trimRight();
    final next = current.isEmpty ? generated : '$current\n\n---\n\n$generated';
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _bodyFocus.requestFocus();
  }

  List<String> _reportLinesForBlock(WorkspaceLiveBlock block) {
    final label = _editorTitleForType(block.type);
    final details = <String>[
      if (block.date.trim().isNotEmpty) block.date.trim(),
      if (block.subtitle.trim().isNotEmpty) block.subtitle.trim(),
    ].join(' · ');
    final lines = <String>[
      '### $label — ${block.title}',
      if (details.isNotEmpty) details,
    ];

    final meta = block.meta;
    void add(String title, List<String> keys) {
      for (final key in keys) {
        final value = '${meta[key] ?? ''}'.trim();
        if (value.isNotEmpty && value.toLowerCase() != 'null') {
          lines.add('• $title: $value');
          return;
        }
      }
    }

    switch (block.type) {
      case WorkspaceLiveBlockType.match:
        add('Соперник', const <String>['opponent', 'opponent_name', 'rival']);
        add('Счёт', const <String>['score', 'result', 'final_score']);
        add('Турнир', const <String>['competition_name', 'competition', 'event_type']);
        break;
      case WorkspaceLiveBlockType.training:
        add('Место', const <String>['location', 'venue', 'place']);
        add('Команда', const <String>['team_name']);
        break;
      case WorkspaceLiveBlockType.plan:
        add('Длительность', const <String>['duration', 'duration_min', 'minutes']);
        add('Игроков', const <String>['players_count', 'player_count']);
        break;
      case WorkspaceLiveBlockType.player:
        add('Команда', const <String>['team_name']);
        add('Амплуа', const <String>['position', 'amplua']);
        add('Номер', const <String>['number', 'shirt_number']);
        break;
      case WorkspaceLiveBlockType.tracker:
        add('Дистанция', const <String>['distance_m', 'total_distance_m']);
        add('Max скорость', const <String>['max_speed_kmh', 'max_speed']);
        add('Max ЧСС', const <String>['max_hr', 'max_bpm', 'heart_rate_max']);
        add('Спринты', const <String>['sprints', 'sprint_count']);
        break;
      case WorkspaceLiveBlockType.testing:
        add('Категория', const <String>['category', 'stage', 'type']);
        break;
      case WorkspaceLiveBlockType.video:
        add('Материал', const <String>['video_title', 'name', 'type']);
        break;
      case WorkspaceLiveBlockType.document:
        add('Тип', const <String>['document_type', 'type', 'mime_type']);
        break;
    }
    lines.add('');
    return lines;
  }

  Future<void> _replaceLiveBlock(int index, WorkspaceLiveBlock block) async {
    if (index < 0 || index >= _liveBlocks.length) return;
    final next = <WorkspaceLiveBlock>[..._liveBlocks];
    next[index] = block;
    setState(() => _liveBlocks = next);
    await _persistLiveBlocks();
  }

  Future<void> _removeLiveBlock(int index) async {
    if (index < 0 || index >= _liveBlocks.length) return;
    final next = <WorkspaceLiveBlock>[..._liveBlocks]..removeAt(index);
    setState(() => _liveBlocks = next);
    await _persistLiveBlocks();
  }

  void _handleEdit() {
    _revision += 1;
    _saveError = false;
    _checkSlashLiveBlockCommand();
    if (mounted) setState(() {});
    if (!widget.readOnly && widget.autoSave && widget.onSave != null) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 1100), _save);
    }
  }

  Future<void> _save() async {
    if (widget.readOnly || widget.onSave == null || !_dirty) return;
    if (_saving) {
      _saveQueued = true;
      return;
    }

    _autoSaveTimer?.cancel();
    final revision = _revision;
    setState(() {
      _saving = true;
      _saveError = false;
    });

    try {
      await widget.onSave!(
        _titleController.text.trim(),
        _bodyController.text,
      );
      if (!mounted) return;
      setState(() {
        _savedRevision = revision;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = true;
      });
    }

    if (!mounted) return;
    final shouldSaveAgain = _saveQueued || _dirty;
    _saveQueued = false;
    if (shouldSaveAgain && !_saveError) {
      _autoSaveTimer = Timer(const Duration(milliseconds: 260), _save);
    }
  }

  Future<void> _requestClose() async {
    if (_saving) {
      _saveQueued = true;
      while (_saving && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
    if (_dirty && widget.onSave != null) await _save();
    if (!mounted || _saveError) return;
    widget.onClose?.call();
  }

  void _wrapSelection(String left, String right) {
    if (widget.readOnly) return;
    final value = _bodyController.value;
    final selection = value.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, value.text.length).toInt()
        : value.text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, value.text.length).toInt()
        : start;
    final selected = value.text.substring(start, end);
    final replacement = '$left$selected$right';
    final text = value.text.replaceRange(start, end, replacement);
    final cursor = selected.isEmpty ? start + left.length : start + replacement.length;
    _bodyController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _bodyFocus.requestFocus();
  }

  void _prefixSelection(String prefix) {
    if (widget.readOnly) return;
    final value = _bodyController.value;
    final selection = value.selection;
    final rawStart = selection.isValid
        ? selection.start.clamp(0, value.text.length).toInt()
        : value.text.length;
    final rawEnd = selection.isValid
        ? selection.end.clamp(rawStart, value.text.length).toInt()
        : rawStart;
    final lineStart =
        value.text.lastIndexOf('\n', rawStart == 0 ? 0 : rawStart - 1) + 1;
    final nextBreak = value.text.indexOf('\n', rawEnd);
    final lineEnd = nextBreak < 0 ? value.text.length : nextBreak;
    final block = value.text.substring(lineStart, lineEnd);
    final replacement =
        block.split('\n').map((line) => '$prefix$line').join('\n');
    _bodyController.value = TextEditingValue(
      text: value.text.replaceRange(lineStart, lineEnd, replacement),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
    _bodyFocus.requestFocus();
  }

  void _insertTemplate(_EditorTemplate template) {
    if (widget.readOnly) return;
    final current = _bodyController.text.trimRight();
    final separator = current.isEmpty ? '' : '\n\n';
    final next = '$current$separator${template.body}';
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _bodyFocus.requestFocus();
  }

  int get _wordCount {
    final value = _bodyController.text.trim();
    if (value.isEmpty) return 0;
    return value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
  }

  Future<void> _copyDocument() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    final value = <String>[title, body].where((part) => part.trim().isNotEmpty).join('\n\n');
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Текст заметки скопирован')),
    );
  }

  List<_EditorTemplate> get _templates {
    final context = widget.contextLabel.toLowerCase();
    if (context.contains('игрок')) {
      return const <_EditorTemplate>[
        _EditorTemplate('Наблюдение', 'Наблюдение за игроком\n\nСильные стороны\n• \n\nЗона развития\n• \n\nСледующий шаг\n☐ '),
        _EditorTemplate('Личная цель', 'Цель игрока\n\nЧто развиваем\n\nКритерий результата\n\nСрок\n\n☐ Контрольная точка'),
        _EditorTemplate('Обратная связь', 'Обратная связь\n\nЧто получилось\n\nЧто улучшить\n\nДоговорённость с игроком'),
        _EditorTemplate('Итоги периода', 'Итоги периода\n\nПрогресс\n\nНагрузка и готовность\n\nПриоритет следующего периода'),
      ];
    }
    if (context.contains('тренер')) {
      return const <_EditorTemplate>[
        _EditorTemplate('Рабочая запись', 'Рабочая запись тренера\n\nЗадача\n\nРешение\n\n☐ Следующее действие'),
        _EditorTemplate('Методика', 'Методическая заметка\n\nЦель\n\nОрганизация\n\nКлючевые подсказки\n\nВарианты усложнения'),
        _EditorTemplate('Разбор', 'Разбор работы\n\nЧто сработало\n\nЧто изменить\n\nРешение на следующую тренировку'),
        _EditorTemplate('Договорённость', 'Договорённость\n\nУчастники\n\nРешение\n\nСрок\n\n☐ Проверить выполнение'),
      ];
    }
    if (context.contains('команд')) {
      return const <_EditorTemplate>[
        _EditorTemplate('Командная цель', 'Командная цель\n\nФокус\n\nКритерий результата\n\n☐ Следующий шаг'),
        _EditorTemplate('Разбор матча', 'Разбор матча\n\nСильные эпизоды\n\nЧто исправить\n\nФокус микроцикла'),
        _EditorTemplate('План недели', 'План недели\n\nГлавная задача\n\nНагрузка\n\nКонтрольные точки'),
        _EditorTemplate('Собрание', 'Итоги собрания\n\nРешения\n\nОтветственные\n\n☐ Следующая встреча'),
      ];
    }
    return const <_EditorTemplate>[
      _EditorTemplate('Быстрая заметка', 'Кратко\n\nГлавная мысль\n\n☐ Следующее действие'),
      _EditorTemplate('Итоги', 'Итоги\n\nЧто сделано\n\nЧто осталось\n\nСледующий шаг'),
      _EditorTemplate('План', 'Цель\n\nШаги\n☐ \n☐ \n☐ \n\nСрок'),
      _EditorTemplate('Встреча', 'Встреча\n\nУчастники\n\nОбсудили\n\nРешили\n\n☐ Контроль'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) {
            _save();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final sidePickerOpen = _sidePickerType != null;
              // Важно: окно Sportoteka OS может быть уже 700 px, хотя весь экран
              // desktop широкий. Поэтому picker не должен зависеть от ширины окна.
              // На широком окне он занимает правую колонку, на узком — выезжает
              // поверх правой части ЭТОГО ЖЕ окна, без route/dialog/bottom sheet.
              final showAside = widget.showTemplates &&
                  constraints.maxWidth >= 1120 &&
                  !sidePickerOpen;
              final splitPicker = sidePickerOpen && constraints.maxWidth >= 860;
              final sideWidth = splitPicker
                  ? (constraints.maxWidth * .36).clamp(330.0, 430.0).toDouble()
                  : (constraints.maxWidth * .88).clamp(280.0, 430.0).toDouble();

              final editorBody = Row(
                children: [
                  if (showAside) _buildAside(),
                  Expanded(child: _buildEditor(compact: compact)),
                  if (splitPicker)
                    SizedBox(
                      width: sideWidth,
                      child: WorkspaceLiveBlockPickerPane(
                        type: _sidePickerType!,
                        onClose: () => setState(() => _sidePickerType = null),
                        onSelected: (block) async => _acceptLiveBlock(block),
                      ),
                    ),
                ],
              );

              return Material(
                color: _surface,
                child: Column(
                  children: [
                    _buildHeader(compact: compact),
                    Expanded(
                      child: sidePickerOpen && !splitPicker
                          ? Stack(
                              children: [
                                Positioned.fill(child: editorBody),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: false,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () => setState(() => _sidePickerType = null),
                                      child: Container(
                                        color: Colors.black.withOpacity(.045),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  bottom: 0,
                                  width: sideWidth,
                                  child: Material(
                                    color: Colors.white,
                                    elevation: 10,
                                    shadowColor: Colors.black.withOpacity(.10),
                                    child: WorkspaceLiveBlockPickerPane(
                                      type: _sidePickerType!,
                                      onClose: () => setState(() => _sidePickerType = null),
                                      onSelected: (block) async => _acceptLiveBlock(block),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : editorBody,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Container(
      height: compact ? 62 : 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (widget.onClose != null) ...[
            _EditorHeaderButton(
              icon: SportotekaWorkspaceIconKind.close,
              tooltip: 'Закрыть редактор',
              onTap: _requestClose,
            ),
            const SizedBox(width: 8),
          ],
          const _EditorMosaicMark(size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SPORTOTEKA OS', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuGroup(color: _green)),
                if (!compact)
                  Text(
                    widget.contextName.trim().isEmpty ? widget.contextLabel : '${widget.contextLabel} · ${widget.contextName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(color: _muted),
                  ),
              ],
            ),
          ),
          _EditorSaveState(
            compact: compact,
            saving: _saving,
            dirty: _dirty,
            failed: _saveError,
            readOnly: widget.readOnly,
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Копировать весь текст',
            onPressed: _copyDocument,
            icon: const Icon(Icons.copy_all_rounded, size: 18, color: _muted),
          ),
          if (!widget.readOnly && widget.onSave != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving || !_dirty ? null : _save,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFFDCE5E0),
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SportotekaWorkspaceIcon(
                    kind: SportotekaWorkspaceIconKind.save,
                    size: 16,
                    color: Colors.white,
                    accentColor: Colors.white,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 7),
                    Text('Сохранить', style: AppTypography.actionStrong(color: Colors.white)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAside() {
    return Container(
      width: 246,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: [
          Text('КОНТЕКСТ', style: AppTypography.menuGroup(color: _muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.contextLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuTitle(color: _text)),
                    ),
                  ],
                ),
                if (widget.contextName.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.contextName, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                ],
                const SizedBox(height: 9),
                Text(widget.documentType, style: AppTypography.caption(color: _muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!widget.readOnly) ...[
            Text('УМНЫЙ ДОКУМЕНТ', style: AppTypography.menuGroup(color: _muted)),
            const SizedBox(height: 9),
            _EditorTemplateButton(title: 'Собрать отчёт из блоков', onTap: _buildSmartReport),
            const SizedBox(height: 22),
          ],
          Text('БЫСТРЫЙ СТАРТ', style: AppTypography.menuGroup(color: _muted)),
          const SizedBox(height: 9),
          for (final template in _templates)
            _EditorTemplateButton(title: template.title, onTap: () => _insertTemplate(template)),
          const SizedBox(height: 22),
          if (!widget.readOnly) ...[
            Text('ЖИВЫЕ БЛОКИ', style: AppTypography.menuGroup(color: _muted)),
            const SizedBox(height: 9),
            _EditorLiveBlockButton(
              title: 'План-конспект',
              subtitle: 'Живой план + PDF snapshot',
              onTap: _insertPlanBlock,
            ),
            const SizedBox(height: 7),
            _EditorLiveBlockButton(
              title: 'Матч',
              subtitle: 'Счёт, соперник и дата',
              iconKind: SportotekaWorkspaceIconKind.matches,
              onTap: () => _insertLiveBlock(WorkspaceLiveBlockType.match),
            ),
            const SizedBox(height: 7),
            _EditorLiveBlockButton(
              title: 'Игрок / Tracker',
              subtitle: 'Игроки и физические данные',
              iconKind: SportotekaWorkspaceIconKind.players,
              onTap: () => _insertLiveBlock(WorkspaceLiveBlockType.player),
            ),
            const SizedBox(height: 22),
          ],
          Text('ПОДСКАЗКА', style: AppTypography.menuGroup(color: _muted)),
          const SizedBox(height: 8),
          Text(
            'Выделите текст и примените формат. ⌘S или Ctrl+S сохраняет документ сразу.',
            style: AppTypography.caption(color: _muted).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor({required bool compact}) {
    return Column(
      children: [
        _EditorToolbar(
          compact: compact,
          readOnly: widget.readOnly,
          onBold: () => _wrapSelection('**', '**'),
          onItalic: () => _wrapSelection('_', '_'),
          onHeading: () => _prefixSelection('## '),
          onBullet: () => _prefixSelection('• '),
          onNumbered: () => _prefixSelection('1. '),
          onChecklist: () => _prefixSelection('☐ '),
          onQuote: () => _prefixSelection('> '),
          onInsert: _insertLiveBlock,
        ),
        if (compact && widget.showTemplates && !widget.readOnly)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: _templates.length + 2,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return ActionChip(
                    onPressed: _buildSmartReport,
                    backgroundColor: const Color(0xFFEAF5EF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    label: Text('Собрать отчёт', style: AppTypography.captionMedium(color: _green)),
                  );
                }
                if (index == 1) {
                  return ActionChip(
                    onPressed: _insertPlanBlock,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    label: Text('+ План-конспект', style: AppTypography.captionMedium(color: _green)),
                  );
                }
                final template = _templates[index - 2];
                return ActionChip(
                  onPressed: () => _insertTemplate(template),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  label: Text(template.title, style: AppTypography.captionMedium(color: _text)),
                );
              },
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 26,
              compact ? 12 : 22,
              compact ? 10 : 26,
              compact ? 28 : 44,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 50,
                    compact ? 22 : 42,
                    compact ? 18 : 50,
                    compact ? 34 : 58,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(compact ? 14 : 18),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x0E142219), blurRadius: 30, spreadRadius: -8, offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _EditorMosaicStrip(),
                          const SizedBox(width: 10),
                          Expanded(child: Text(widget.documentType.toUpperCase(), style: AppTypography.menuGroup(color: _muted))),
                          Text(_todayLabel(), style: AppTypography.caption(color: _muted)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _titleController,
                        readOnly: widget.readOnly || widget.titleReadOnly,
                        maxLines: null,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Название заметки',
                          hintStyle: AppTypography.screenTitle(color: const Color(0xFFAAB2AD)).copyWith(fontSize: compact ? 21 : 28),
                        ),
                        style: AppTypography.screenTitle(color: _text).copyWith(fontSize: compact ? 21 : 28, height: 1.16),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _EditorMetaChip(text: widget.contextLabel),
                          if (widget.contextName.trim().isNotEmpty) _EditorMetaChip(text: widget.contextName),
                          _EditorMetaChip(text: '$_wordCount слов'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(height: 1, color: _line),
                      const SizedBox(height: 18),
                      if (_liveBlocksLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: LinearProgressIndicator(minHeight: 2, color: _green, backgroundColor: Color(0xFFEAF1ED)),
                        ),
                      if (_liveBlocks.isNotEmpty) ...[
                        Row(
                          children: [
                            Text('СВЯЗАННЫЕ МАТЕРИАЛЫ', style: AppTypography.menuGroup(color: _muted)),
                            const SizedBox(width: 8),
                            const _EditorMosaicStrip(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (int index = 0; index < _liveBlocks.length; index++) ...[
                          WorkspaceLiveBlockCard(
                            key: ValueKey('${_liveBlocks[index].type.name}:${_liveBlocks[index].entityId}'),
                            block: _liveBlocks[index],
                            readOnly: widget.readOnly,
                            onChanged: (value) => _replaceLiveBlock(index, value),
                            onRemove: () => _removeLiveBlock(index),
                          ),
                          const SizedBox(height: 9),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: _line),
                        const SizedBox(height: 18),
                      ] else
                        const SizedBox(height: 4),
                      TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        readOnly: widget.readOnly,
                        minLines: compact ? 20 : 26,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Начните писать или выберите шаблон заметки…',
                          hintStyle: AppTypography.body(color: const Color(0xFFA2ABA5)).copyWith(fontSize: compact ? 14 : 15, height: 1.62),
                        ),
                        style: AppTypography.body(color: _text).copyWith(fontSize: compact ? 14 : 15, height: 1.62),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Text('$_wordCount слов · ${_bodyController.text.length} знаков', style: AppTypography.caption(color: _muted)),
              const Spacer(),
              if (!compact)
                Text(
                  widget.autoSave && widget.onSave != null ? 'Автосохранение включено' : 'Сохранение вручную',
                  style: AppTypography.caption(color: _muted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.day)}.${two(now.month)}.${now.year}';
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.compact,
    required this.readOnly,
    required this.onBold,
    required this.onItalic,
    required this.onHeading,
    required this.onBullet,
    required this.onNumbered,
    required this.onChecklist,
    required this.onQuote,
    required this.onInsert,
  });

  final bool compact;
  final bool readOnly;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeading;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onChecklist;
  final VoidCallback onQuote;
  final ValueChanged<WorkspaceLiveBlockType> onInsert;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.heading, tooltip: 'Заголовок', onTap: onHeading),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.bold, tooltip: 'Жирный', onTap: onBold),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.italic, tooltip: 'Курсив', onTap: onItalic),
      const _EditorToolDivider(),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.bullets, tooltip: 'Список', onTap: onBullet),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.numbered, tooltip: 'Нумерованный список', onTap: onNumbered),
      _EditorTextToolButton(label: '☐', tooltip: 'Задача', onTap: onChecklist),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.quote, tooltip: 'Цитата', onTap: onQuote),
      const _EditorToolDivider(),
      _EditorInsertButton(onInsert: onInsert),
    ];

    return IgnorePointer(
      ignoring: readOnly,
      child: Opacity(
        opacity: readOnly ? .48 : 1,
        child: Container(
          height: compact ? 49 : 54,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _WorkspaceDocumentEditorState._line)),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                const SizedBox(width: 16),
                Text('ФОРМАТ', style: AppTypography.menuGroup(color: _WorkspaceDocumentEditorState._muted)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 0, vertical: 5),
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorInsertButton extends StatelessWidget {
  const _EditorInsertButton({required this.onInsert});
  final ValueChanged<WorkspaceLiveBlockType> onInsert;

  @override
  Widget build(BuildContext context) {
    const entries = <WorkspaceLiveBlockType>[
      WorkspaceLiveBlockType.plan,
      WorkspaceLiveBlockType.match,
      WorkspaceLiveBlockType.training,
      WorkspaceLiveBlockType.player,
      WorkspaceLiveBlockType.tracker,
      WorkspaceLiveBlockType.testing,
      WorkspaceLiveBlockType.video,
      WorkspaceLiveBlockType.document,
    ];
    return PopupMenuButton<WorkspaceLiveBlockType>(
      tooltip: 'Вставить',
      color: Colors.white,
      onSelected: onInsert,
      itemBuilder: (_) => <PopupMenuEntry<WorkspaceLiveBlockType>>[
        for (final type in entries)
          PopupMenuItem<WorkspaceLiveBlockType>(
            value: type,
            child: Row(
              children: [
                SportotekaWorkspaceIcon(kind: _editorIconForType(type), size: 19, color: const Color(0xFF0B8F55)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_editorTitleForType(type), style: AppTypography.menuTitle(color: const Color(0xFF101814))),
                      Text(_editorSubtitleForType(type), style: AppTypography.caption(color: const Color(0xFF758079))),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Tooltip(
        message: 'Вставить',
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0B8F55)),
                const SizedBox(width: 5),
                Text('Вставить', style: AppTypography.actionStrong(color: const Color(0xFF0B8F55))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

SportotekaWorkspaceIconKind _editorIconForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan: return SportotekaWorkspaceIconKind.plans;
    case WorkspaceLiveBlockType.match: return SportotekaWorkspaceIconKind.matches;
    case WorkspaceLiveBlockType.training: return SportotekaWorkspaceIconKind.trainings;
    case WorkspaceLiveBlockType.player: return SportotekaWorkspaceIconKind.players;
    case WorkspaceLiveBlockType.tracker: return SportotekaWorkspaceIconKind.tracker;
    case WorkspaceLiveBlockType.testing: return SportotekaWorkspaceIconKind.testing;
    case WorkspaceLiveBlockType.video: return SportotekaWorkspaceIconKind.video;
    case WorkspaceLiveBlockType.document: return SportotekaWorkspaceIconKind.documents;
  }
}

String _editorTitleForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan: return 'План-конспект';
    case WorkspaceLiveBlockType.match: return 'Матч';
    case WorkspaceLiveBlockType.training: return 'Тренировка';
    case WorkspaceLiveBlockType.player: return 'Игрок';
    case WorkspaceLiveBlockType.tracker: return 'Tracker';
    case WorkspaceLiveBlockType.testing: return 'Тестирование';
    case WorkspaceLiveBlockType.video: return 'Видео';
    case WorkspaceLiveBlockType.document: return 'Документ';
  }
}

String _editorSubtitleForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan: return 'Живой план + PDF snapshot';
    case WorkspaceLiveBlockType.match: return 'Соперник, счёт и дата';
    case WorkspaceLiveBlockType.training: return 'Событие, место и команда';
    case WorkspaceLiveBlockType.player: return 'Карточка игрока';
    case WorkspaceLiveBlockType.tracker: return 'GPS, скорость и ЧСС';
    case WorkspaceLiveBlockType.testing: return 'Реальная тестовая сессия';
    case WorkspaceLiveBlockType.video: return 'Видеораздел / материал';
    case WorkspaceLiveBlockType.document: return 'Документ из архива';
  }
}

class _EditorLiveBlockButton extends StatelessWidget {
  const _EditorLiveBlockButton({required this.title, required this.subtitle, required this.onTap, this.iconKind = SportotekaWorkspaceIconKind.plans});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final SportotekaWorkspaceIconKind iconKind;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.72),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              SportotekaWorkspaceIcon(kind: iconKind, size: 22, color: const Color(0xFF0B8F55)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.menuTitle(color: const Color(0xFF101814))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.caption(color: const Color(0xFF758079))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorToolButton extends StatelessWidget {
  const _EditorToolButton({required this.icon, required this.tooltip, required this.onTap});

  final SportotekaWorkspaceIconKind icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(child: SportotekaWorkspaceIcon(kind: icon, size: 19)),
        ),
      ),
    );
  }
}

class _EditorTextToolButton extends StatelessWidget {
  const _EditorTextToolButton({required this.label, required this.tooltip, required this.onTap});

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(child: Text(label, style: AppTypography.itemTitle(color: const Color(0xFF29332D)))),
        ),
      ),
    );
  }
}

class _EditorToolDivider extends StatelessWidget {
  const _EditorToolDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E5E1)),
    );
  }
}

class _EditorHeaderButton extends StatelessWidget {
  const _EditorHeaderButton({required this.icon, required this.tooltip, required this.onTap});

  final SportotekaWorkspaceIconKind icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(child: SportotekaWorkspaceIcon(kind: icon, size: 19)),
        ),
      ),
    );
  }
}

class _EditorSaveState extends StatelessWidget {
  const _EditorSaveState({required this.compact, required this.saving, required this.dirty, required this.failed, required this.readOnly});

  final bool compact;
  final bool saving;
  final bool dirty;
  final bool failed;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? const Color(0xFFB04444)
        : dirty || saving
            ? const Color(0xFF9B7420)
            : const Color(0xFF0B8F55);
    final text = readOnly
        ? 'Только чтение'
        : failed
            ? 'Не синхронизировано'
            : saving
                ? 'Сохраняется'
                : dirty
                    ? 'Есть изменения'
                    : 'Сохранено';

    if (compact) {
      return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.captionMedium(color: color)),
        ],
      ),
    );
  }
}

class _EditorTemplateButton extends StatelessWidget {
  const _EditorTemplateButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.white.withOpacity(.68),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                const _EditorMosaicStrip(compact: true),
                const SizedBox(width: 9),
                Expanded(child: Text(title, style: AppTypography.menuTitle(color: const Color(0xFF263129)))),
                const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.chevronRight, size: 15, color: Color(0xFF78837C)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorMetaChip extends StatelessWidget {
  const _EditorMetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF0F4F1), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption(color: const Color(0xFF637068)),
      ),
    );
  }
}

class _EditorMosaicMark extends StatelessWidget {
  const _EditorMosaicMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * .18;
    return SizedBox.square(
      dimension: size,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: size * .10,
        runSpacing: size * .10,
        children: List<Widget>.generate(9, (index) {
          const colors = <Color>[
            Color(0xFFC4DED0), Color(0xFF8FC2A6), Color(0xFFDCECE3),
            Color(0xFF75B492), Color(0xFF0B8F55), Color(0xFFAED3BF),
            Color(0xFFD5E8DD), Color(0xFF66AA86), Color(0xFFBADBC9),
          ];
          return Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: colors[index], shape: BoxShape.circle),
          );
        }),
      ),
    );
  }
}

class _EditorMosaicStrip extends StatelessWidget {
  const _EditorMosaicStrip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 4.0 : 5.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: index == 1 ? const Color(0xFF0B8F55) : const Color(0xFFAED3BF),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorTemplate {
  const _EditorTemplate(this.title, this.body);

  final String title;
  final String body;
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
