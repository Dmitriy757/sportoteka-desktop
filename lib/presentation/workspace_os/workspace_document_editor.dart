import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_context_ai_layer.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_attachment_preview.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_live_blocks.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_training_plan_codec.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/api/training_graphics_api.dart';

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
    this.aiClubId,
    this.aiUserId,
    this.aiTeamId,
    this.aiClubName = '',
    this.aiTeamName = '',
    this.aiDocumentKey,
    this.aiExtraPayload = const <String, dynamic>{},
    this.onUploadImage,
    this.compactWorkspaceChrome = false,
    this.startWithTrainingPlanTemplate = false,
    this.initialTrainingPlanData = const <String, dynamic>{},
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
  final int? aiClubId;
  final int? aiUserId;
  final int? aiTeamId;
  final String aiClubName;
  final String aiTeamName;
  final String? aiDocumentKey;
  final Map<String, dynamic> aiExtraPayload;
  final Future<String?> Function(String filePath)? onUploadImage;

  /// Для документов, уже открытых внутри плавающего окна SPORTOTEKA OS.
  /// В этом режиме внешняя шапка окна/сущности уже показывает название,
  /// поэтому внутренний ряд SPORTOTEKA OS + Save скрывается, как в Word.
  final bool compactWorkspaceChrome;

  /// Opens the document immediately as the canonical Workspace plan-conspект.
  /// Used by both Workspace OS and the Plans module, so there is only one
  /// creation/editing surface.
  final bool startWithTrainingPlanTemplate;
  final Map<String, dynamic> initialTrainingPlanData;

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
  String _lastObservedTitle = '';
  String _lastObservedBody = '';

  static const Duration _autoSaveIdleDelay = Duration(milliseconds: 2800);
  static const Duration _autoSaveRetryDelay = Duration(milliseconds: 1200);

  List<WorkspaceLiveBlock> _liveBlocks = <WorkspaceLiveBlock>[];
  bool _liveBlocksLoading = false;
  bool _slashLiveBlockPending = false;

  // На широком экране вставка живого блока открывается прямо внутри
  // текущего окна редактора — отдельной правой панелью, а не modal/bottom sheet.
  WorkspaceLiveBlockType? _sidePickerType;
  bool _aiExpanded = false;
  bool _showImportedTextBlock = true;

  // Word-подобный режим: текст хранится в переносимом markdown-подобном
  // формате, но на странице отображается как визуальный документ.
  bool _visualMode = true;
  int? _activeVisualBlockStart;
  int? _activeVisualBlockEnd;
  _WorkspaceRichTextController? _visualBlockController;
  FocusNode? _visualBlockFocus;
  int? _selectedImageStart;
  int? _selectedTableStart;
  double _imageResizeDrag = 0;

  bool _trainingPlanSchemeLoading = false;
  int? _trainingPlanSchemeLoadingExercise;

  // Training Graphics picker lives inside the CURRENT Sportoteka OS window.
  // No Navigator push to Plans, so choosing a scheme never drops the user
  // back to the Workspace desktop.
  bool _trainingGraphicsPickerOpen = false;
  _WorkspaceDocBlock? _trainingGraphicsPickerBlock;
  Map<String, dynamic>? _trainingGraphicsPickerPlan;
  int? _trainingGraphicsPickerExerciseIndex;
  List<int> _trainingGraphicsPickerPreselected = <int>[];

  final List<String> _bodyHistory = <String>[];
  int _bodyHistoryIndex = -1;
  bool _historyRestoring = false;
  String _lastHistoryBody = '';

  bool get _canUndo => _bodyHistoryIndex > 0;
  bool get _canRedo =>
      _bodyHistoryIndex >= 0 && _bodyHistoryIndex < _bodyHistory.length - 1;

  bool get _dirty => _revision != _savedRevision;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _lastObservedTitle = _titleController.text;
    _lastObservedBody = _bodyController.text;
    _titleController.addListener(_handleEdit);
    _bodyController.addListener(_handleEdit);
    _lastHistoryBody = _bodyController.text;
    _bodyHistory.add(_bodyController.text);
    _bodyHistoryIndex = 0;
    _loadLiveBlocks();
    if (widget.startWithTrainingPlanTemplate &&
        widget.initialBody.trim().isEmpty &&
        !widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _bodyController.text.trim().isNotEmpty) return;
        _insertTrainingPlanTemplate(seed: widget.initialTrainingPlanData);
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorkspaceDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final blocksKeyChanged =
        _liveBlocksKeyFor(oldWidget) != _effectiveLiveBlocksKey;
    if (blocksKeyChanged) _loadLiveBlocks();
    if (_dirty || _saving) return;
    final titleChanged = oldWidget.initialTitle != widget.initialTitle;
    final bodyChanged = oldWidget.initialBody != widget.initialBody;
    if (!titleChanged && !bodyChanged) return;

    _titleController.removeListener(_handleEdit);
    _bodyController.removeListener(_handleEdit);
    if (titleChanged) _titleController.text = widget.initialTitle;
    if (bodyChanged) _bodyController.text = widget.initialBody;
    _lastObservedTitle = _titleController.text;
    _lastObservedBody = _bodyController.text;
    _titleController.addListener(_handleEdit);
    _bodyController.addListener(_handleEdit);
    _revision = 0;
    _savedRevision = 0;
    if (bodyChanged) {
      _lastHistoryBody = _bodyController.text;
      _bodyHistory
        ..clear()
        ..add(_bodyController.text);
      _bodyHistoryIndex = 0;
      _finishVisualBlockEditing(rebuild: false);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_handleEdit);
    _bodyController.removeListener(_handleEdit);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    _visualBlockController?.dispose();
    _visualBlockFocus?.dispose();
    super.dispose();
  }

  String _liveBlocksKeyFor(WorkspaceDocumentEditor source) {
    final explicit = source.liveBlocksKey?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final seed =
        '${source.contextLabel}|${source.contextName}|${source.documentType}|${source.initialTitle}';
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
      final blocks = await WorkspaceLiveBlocksRepository(
              documentKey: _effectiveLiveBlocksKey)
          .load();
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
      await WorkspaceLiveBlocksRepository(documentKey: _effectiveLiveBlocksKey)
          .save(_liveBlocks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Изменение сохранено локально, но пока не синхронизировано с сервером')),
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
            final next =
                current.substring(0, current.length - reportCommand.length);
            _bodyController.value = TextEditingValue(
                text: next,
                selection: TextSelection.collapsed(offset: next.length));
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
      if (lower.endsWith(entry.key)) {
        command = entry.key;
        type = entry.value;
        break;
      }
    }
    if (command.isEmpty || type == null) return;
    _slashLiveBlockPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final current = _bodyController.text;
      if (current.toLowerCase().endsWith(command)) {
        final next = current.substring(0, current.length - command.length);
        _bodyController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length));
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
        : (media.size.width < media.size.height
            ? media.size.width
            : media.size.height);

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
        ((item.entityId > 0 &&
                block.entityId > 0 &&
                item.entityId == block.entityId) ||
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

  Future<void> _insertPlanBlock() =>
      _insertLiveBlock(WorkspaceLiveBlockType.plan);

  Future<void> _buildSmartReport() async {
    if (widget.readOnly) return;
    if (_liveBlocks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Сначала вставьте Матч, План, Игрока, Tracker или другой живой блок')),
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
      if (widget.contextName.trim().isNotEmpty)
        'Контекст: ${widget.contextName.trim()}',
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
        add('Турнир',
            const <String>['competition_name', 'competition', 'event_type']);
        break;
      case WorkspaceLiveBlockType.training:
        add('Место', const <String>['location', 'venue', 'place']);
        add('Команда', const <String>['team_name']);
        break;
      case WorkspaceLiveBlockType.plan:
        add('Длительность',
            const <String>['duration', 'duration_min', 'minutes']);
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
    // TextEditingController also notifies when only caret/selection changes.
    // Cursor movement must never mark the document dirty or start autosave.
    final title = _titleController.text;
    final body = _bodyController.text;
    final titleChanged = title != _lastObservedTitle;
    final bodyChanged = body != _lastObservedBody;
    if (!titleChanged && !bodyChanged) return;

    _lastObservedTitle = title;
    _lastObservedBody = body;
    _revision += 1;
    _saveError = false;

    if (!_historyRestoring && bodyChanged && body != _lastHistoryBody) {
      if (_bodyHistoryIndex < _bodyHistory.length - 1) {
        _bodyHistory.removeRange(_bodyHistoryIndex + 1, _bodyHistory.length);
      }
      _bodyHistory.add(body);
      if (_bodyHistory.length > 80) {
        _bodyHistory.removeAt(0);
      }
      _bodyHistoryIndex = _bodyHistory.length - 1;
      _lastHistoryBody = body;
    }

    if (bodyChanged) _checkSlashLiveBlockCommand();
    if (mounted) setState(() {});

    // Quiet autosave only after a real pause in content editing.
    if (!widget.readOnly && widget.autoSave && widget.onSave != null) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(_autoSaveIdleDelay, _save);
    }
  }

  void _restoreHistoryAt(int index) {
    if (index < 0 || index >= _bodyHistory.length) return;
    _finishVisualBlockEditing(rebuild: false);
    _historyRestoring = true;
    final text = _bodyHistory[index];
    _bodyController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _historyRestoring = false;
    _bodyHistoryIndex = index;
    _lastHistoryBody = text;
    if (mounted) setState(() {});
  }

  void _undo() {
    if (widget.readOnly || !_canUndo) return;
    _restoreHistoryAt(_bodyHistoryIndex - 1);
  }

  void _redo() {
    if (widget.readOnly || !_canRedo) return;
    _restoreHistoryAt(_bodyHistoryIndex + 1);
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
      _autoSaveTimer = Timer(_autoSaveRetryDelay, _save);
    }
  }

  String _safeExportFileName(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) value = 'Документ Sportoteka';
    return value.length > 90 ? value.substring(0, 90).trim() : value;
  }

  String _exportPlainText(String raw) {
    var value = raw;
    value = value.split('\n').map((line) {
      final plan = _decodeTrainingPlanToken(line);
      if (plan == null) return line;
      final exercises = _trainingPlanExercises(plan);
      final b = StringBuffer()
        ..writeln('План-конспект тренировки')
        ..writeln('Недельный цикл: ${plan['cycle'] ?? ''}')
        ..writeln('Дата: ${plan['date'] ?? ''}')
        ..writeln('Клуб: ${plan['club'] ?? ''}')
        ..writeln('Тренеры: ${plan['trainers'] ?? ''}')
        ..writeln('Команда: ${plan['team'] ?? ''}')
        ..writeln('Тема: ${plan['theme'] ?? ''}');
      for (var i = 0; i < exercises.length; i++) {
        b.writeln('${i + 1}. ${exercises[i]['title'] ?? 'Упражнение'}');
      }
      return b.toString().trimRight();
    }).join('\n');

    value = value.replaceAll(RegExp(r'^<align:(?:left|center|right|justify)>', multiLine: true), '');
    value = value.replaceAll(RegExp(r'<fs:\d{1,2}>|</fs>'), '');
    value = value.replaceAll(RegExp(r'<c:[0-9A-Fa-f]{6,8}>|</c>'), '');
    value = value.replaceAll(RegExp(r'<bg:[0-9A-Fa-f]{6,8}>|</bg>'), '');
    value = value.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^\)]+)\)\{width=\d+%(?:;align=(?:left|center|right))?\}'),
      (m) {
        final caption = (m.group(1) ?? '').trim();
        return caption.isEmpty ? '[Изображение]' : '[Изображение: $caption]';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^\)]+)\)'),
      (m) => '${m.group(1)} (${m.group(2)})',
    );
    value = value.replaceAll('**', '');
    value = value.replaceAll('__', '');
    value = value.replaceAll('~~', '');
    value = value.replaceAllMapped(
      RegExp(r'(?<!\w)_(.+?)_(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    return value;
  }

  String _htmlEscape(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  String _inlineDocHtml(String raw) {
    var value = raw;
    value = value.replaceAll(RegExp(r'<fs:\d{1,2}>|</fs>'), '');
    value = value.replaceAll(RegExp(r'<c:[0-9A-Fa-f]{6,8}>|</c>'), '');
    value = value.replaceAll(RegExp(r'<bg:[0-9A-Fa-f]{6,8}>|</bg>'), '');
    value = _htmlEscape(value);
    value = value.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*'), (m) => '<b>${m.group(1)}</b>');
    value = value.replaceAllMapped(
        RegExp(r'__(.+?)__'), (m) => '<u>${m.group(1)}</u>');
    value = value.replaceAllMapped(
        RegExp(r'~~(.+?)~~'), (m) => '<s>${m.group(1)}</s>');
    value = value.replaceAllMapped(
        RegExp(r'(?<!\w)_(.+?)_(?!\w)'), (m) => '<i>${m.group(1)}</i>');
    value = value.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((https?://[^\)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );
    return value;
  }


  String _trainingPlanDocHtml(Map<String, dynamic> plan) {
    String g(String key) => _htmlEscape('${plan[key] ?? ''}');
    final exercises = _trainingPlanExercises(plan);
    final out = StringBuffer();

    final logoHidden = plan['team_logo_hidden'] == true;
    final logoData = '${plan['team_logo_data'] ?? ''}'.trim();
    final logoUrl = _normalizeTrainingPlanLogoUrl(plan['team_logo_url']);
    final logoSource = logoData.isNotEmpty ? logoData : logoUrl;
    final logoHtml = logoHidden
        ? ''
        : (logoSource.isEmpty
            ? '<div class="plan-logo-fallback"><b>SPORTOTEKA</b></div>'
            : '<img class="plan-team-logo" '
                'src="${_htmlEscape(logoSource)}" '
                'width="128" height="128" '
                'style="width:96pt;height:96pt;'
                'max-width:96pt;max-height:96pt;'
                'mso-width-percent:0;" '
                'alt="Логотип команды">');

    out.writeln('<div class="sportoteka-plan">');

    out.writeln(
      '<table class="plan-header" width="100%" cellspacing="0" cellpadding="0">'
      '<colgroup><col width="27%"><col width="73%"></colgroup>'
      '<tr>'
      '<td class="plan-logo-cell" width="27%" valign="middle" align="center">'
      '$logoHtml'
      '</td>'
      '<td class="plan-header-info" width="73%" valign="top">'
      '<table class="plan-meta" width="100%" cellspacing="0" cellpadding="0">'
      '<colgroup><col width="34%"><col width="33%"><col width="33%"></colgroup>'
      '<tr><td colspan="3" class="plan-cycle" align="center">'
      '<b>Недельный цикл</b> ${g('cycle')}'
      '<span class="plan-date"><b>Дата:</b> ${g('date')}</span>'
      '</td></tr>'
      '<tr>'
      '<td width="34%"><b>Клуб:</b><br>${g('club')}</td>'
      '<td width="33%"><b>Тренеры:</b><br>${g('trainers')}</td>'
      '<td width="33%"><b>Команда:</b><br>${g('team')}</td>'
      '</tr>'
      '<tr>'
      '<td width="34%"><b>Место проведения:</b><br>${g('location')}</td>'
      '<td width="33%"><b>К-во игроков:</b><br>${g('players_count')}</td>'
      '<td width="33%"><b>Продолжительность:</b><br>${g('duration_min')} мин.</td>'
      '</tr>'
      '<tr>'
      '<td width="34%"><b>Тема:</b></td>'
      '<td colspan="2">${g('theme')}</td>'
      '</tr>'
      '</table>'
      '</td>'
      '</tr>'
      '</table>',
    );

    out.writeln(
      '<table class="plan-goals" width="100%" cellspacing="0" cellpadding="0">'
      '<colgroup>'
      '<col width="13%"><col width="21.75%"><col width="21.75%">'
      '<col width="21.75%"><col width="21.75%">'
      '</colgroup>'
      '<tr>'
      '<td rowspan="2" width="13%" class="plan-section-label"><b>Цели:</b></td>'
      '<th width="21.75%">Техника</th>'
      '<th width="21.75%">Тактика</th>'
      '<th width="21.75%">Фитнес</th>'
      '<th width="21.75%">Ментальность</th>'
      '</tr>'
      '<tr>'
      '<td>${g('goal_tech')}</td>'
      '<td>${g('goal_tact')}</td>'
      '<td>${g('goal_fit')}</td>'
      '<td>${g('goal_ment')}</td>'
      '</tr>'
      '</table>',
    );

    out.writeln(
      '<table class="plan-equipment" width="100%" cellspacing="0" cellpadding="0">'
      '<colgroup><col width="16%"><col width="84%"></colgroup>'
      '<tr>'
      '<td width="16%" class="plan-section-label"><b>Инвентарь:</b></td>'
      '<td width="84%">${g('equipment')}</td>'
      '</tr>'
      '</table>',
    );

    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      String eg(String key) => _htmlEscape('${e[key] ?? ''}');
      final schemes =
          e['schemes'] is List ? e['schemes'] as List : const <dynamic>[];
      String preview = '';
      if (schemes.isNotEmpty && schemes.first is Map) {
        preview = _trainingGraphicAbsoluteUrl(
          '${(schemes.first as Map)['preview_url'] ?? (schemes.first as Map)['preview'] ?? ''}',
        );
      }

      final rawTitle = eg('title').trim();
      final exerciseTitle = rawTitle.isEmpty ? 'Упражнение' : rawTitle;

      out.writeln(
        '<table class="exercise" width="100%" cellspacing="0" cellpadding="0">'
        '<colgroup><col width="62%"><col width="38%"></colgroup>'
        '<tr class="exercise-title-row">'
        '<td width="62%" class="exercise-title"><b>${i + 1}. $exerciseTitle</b></td>'
        '<td width="38%" class="exercise-duration" align="right">'
        '<b>Продолжительность: ${eg('duration_min')} мин.</b>'
        '</td>'
        '</tr>'
        '<tr>'
        '<td width="62%" class="exercise-scheme" valign="middle" align="center">'
        '${preview.isEmpty ? '<span class="empty-scheme">Схема не прикреплена</span>' : '<img class="exercise-scheme-image" src="${_htmlEscape(preview)}" alt="Схема упражнения">'}'
        '</td>'
        '<td width="38%" class="exercise-details" valign="top">'
        '<table class="exercise-metrics" width="100%" cellspacing="0" cellpadding="0">'
        '<colgroup><col width="25%"><col width="25%"><col width="25%"><col width="25%"></colgroup>'
        '<tr>'
        '<th>Интенсивность</th><th>К-во<br>повторений</th>'
        '<th>Время<br>работы</th><th>Пауза</th>'
        '</tr>'
        '<tr>'
        '<td>${eg('intensity')}</td><td>${eg('repetitions')}</td>'
        '<td>${eg('work_time')}</td><td>${eg('pause_time')}</td>'
        '</tr>'
        '</table>'
        '<table class="exercise-text-block" width="100%" cellspacing="0" cellpadding="0">'
        '<tr><td><b>Организация:</b><br>${eg('organization')}</td></tr>'
        '</table>'
        '<table class="exercise-text-block" width="100%" cellspacing="0" cellpadding="0">'
        '<tr><td><b>Тренерский акцент:</b><br>${eg('coach_focus')}</td></tr>'
        '</table>'
        '</td>'
        '</tr>'
        '</table>',
      );
    }

    out.writeln(
      '<table class="plan-signature" width="100%" cellspacing="0" cellpadding="0">'
      '<colgroup><col width="45%"><col width="55%"></colgroup>'
      '<tr>'
      '<td width="45%"><b>План-конспект составил</b><br>${g('signed_role')}</td>'
      '<td width="55%" align="right"><b>${g('signed_by')}</b></td>'
      '</tr>'
      '</table>',
    );

    out.writeln('</div>');
    return out.toString();
  }

  String _docBodyHtml() {
    final out = StringBuffer();
    for (final rawLine in _bodyController.text.split('\n')) {
      final plan = _decodeTrainingPlanToken(rawLine);
      if (plan != null) {
        out.writeln(_trainingPlanDocHtml(plan));
        continue;
      }
      var line = rawLine;
      var align = 'left';
      final alignMatch =
          RegExp(r'^<align:(left|center|right|justify)>').firstMatch(line);
      if (alignMatch != null) {
        align = alignMatch.group(1) ?? 'left';
        line = line.substring(alignMatch.end);
      }

      final image = _WorkspaceVisualImageData.tryParse(line);
      if (image != null) {
        final caption = image.caption.trim().isEmpty
            ? 'Изображение'
            : image.caption.trim();
        final width = image.widthPercent.clamp(20, 100);
        out.writeln(
          '<div style="text-align:${image.alignment};margin:8pt 0">'
          '<img src="${_htmlEscape(image.url)}" '
          'style="width:${width}%;max-width:100%;height:auto"><br>'
          '<span style="color:#667085;font-size:9.5pt">'
          '${_htmlEscape(caption)}</span></div>',
        );
        continue;
      }
      if (line.trim() == '---') {
        out.writeln('<hr>');
        continue;
      }
      if (line.trim().isEmpty) {
        out.writeln('<p>&nbsp;</p>');
        continue;
      }

      var tag = 'p';
      var content = line;
      if (content.startsWith('### ')) {
        tag = 'h3';
        content = content.substring(4);
      } else if (content.startsWith('## ')) {
        tag = 'h2';
        content = content.substring(3);
      } else if (content.startsWith('# ')) {
        tag = 'h1';
        content = content.substring(2);
      } else if (content.startsWith('> ')) {
        tag = 'blockquote';
        content = content.substring(2);
      }
      out.writeln(
          '<$tag style="text-align:$align">${_inlineDocHtml(content)}</$tag>');
    }
    return out.toString();
  }

  String _exportFileName(String extension) {
    final title = _titleController.text.trim().isEmpty
        ? 'Документ Sportoteka'
        : _titleController.text.trim();
    return '${_safeExportFileName(title)}_${_exportStamp()}.$extension';
  }

  Future<String?> _chooseExportPath({
    required String extension,
    required String dialogTitle,
  }) async {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: _exportFileName(extension),
      type: FileType.custom,
      allowedExtensions: <String>[extension],
    );
  }

  Future<Directory> _shareExportDirectory() async {
    final dir = await getTemporaryDirectory();
    final sportoteka = Directory(
      '${dir.path}${Platform.pathSeparator}Sportoteka',
    );
    if (!await sportoteka.exists()) {
      await sportoteka.create(recursive: true);
    }
    return sportoteka;
  }

  String _ensureExportExtension(String path, String extension) {
    final clean = path.trim();
    if (clean.toLowerCase().endsWith('.${extension.toLowerCase()}')) {
      return clean;
    }
    return '$clean.$extension';
  }

  String _exportStamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }

  Future<File> _createDocFile({String? outputPath}) async {
    final title = _titleController.text.trim().isEmpty
        ? 'Документ Sportoteka'
        : _titleController.text.trim();
    final String path;
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      path = _ensureExportExtension(outputPath, 'doc');
    } else {
      final dir = await _shareExportDirectory();
      path = '${dir.path}${Platform.pathSeparator}${_exportFileName('doc')}';
    }
    final file = File(path);
    final html = '''<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN">
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="ProgId" content="Word.Document">
<meta name="Generator" content="Sportoteka OS">
<style>
@page Section1 {
  size: 595.3pt 841.9pt;
  margin: 30pt 30pt 30pt 30pt;
  mso-header-margin: 0pt;
  mso-footer-margin: 0pt;
}
div.Section1 { page: Section1; width:100%; }
html,body { background:#fff; margin:0; padding:0; }
body {
  font-family:Arial,sans-serif;
  font-size:10.5pt;
  line-height:1.25;
  color:#101814;
}
h1{font-size:19pt;margin:0 0 10pt;}
h2{font-size:15pt;margin:12pt 0 6pt;}
h3{font-size:12.5pt;margin:10pt 0 5pt;}
p{margin:0 0 6pt;}
blockquote{
  border-left:3px solid #0B8F55;
  padding-left:10pt;
  color:#475467;
  margin:8pt 0;
}
table{
  border-collapse:collapse;
  border-spacing:0;
  width:100%;
  table-layout:fixed;
  mso-table-layout-alt:fixed;
}
td,th{
  border:1px solid #555;
  padding:4.5pt;
  vertical-align:top;
  word-wrap:break-word;
  overflow-wrap:break-word;
}
th{background:#f2f4f3;font-weight:700;text-align:center;}

.sportoteka-plan{width:100%;margin:0;padding:0;}
.sportoteka-plan table{margin:0;}
.plan-header{margin:0 0 5pt 0 !important;}
.plan-logo-cell{
  height:150pt;
  text-align:center;
  vertical-align:middle !important;
  padding:9pt !important;
}
.plan-team-logo{
  /* Word can ignore max-width on imported HTML images, therefore
     the <img> also has explicit width/height attributes (128px / 96pt). */
  width:96pt !important;
  height:96pt !important;
  max-width:96pt !important;
  max-height:96pt !important;
  object-fit:contain;
}
.plan-logo-fallback{color:#0B8F55;font-size:9pt;text-align:center;}
.plan-header-info{padding:0 !important;}
.plan-meta{width:100%;height:150pt;}
.plan-meta td{font-size:9.3pt;padding:4pt;}
.plan-cycle{height:24pt;vertical-align:middle !important;}
.plan-date{float:right;font-weight:400;}
.plan-goals{margin:0 0 5pt 0 !important;}
.plan-goals th,.plan-goals td{height:27pt;font-size:9.2pt;}
.plan-section-label{vertical-align:top !important;}
.plan-equipment{margin:0 0 6pt 0 !important;}
.plan-equipment td{height:28pt;}

.exercise{
  margin:7pt 0 0 0 !important;
  page-break-inside:avoid;
  mso-break-inside:avoid;
}
.exercise-title-row td{
  background:#fff;
  vertical-align:middle !important;
  height:24pt;
}
.exercise-title{font-size:10pt;}
.exercise-duration{font-size:9.2pt;white-space:nowrap;}
.exercise-scheme{
  height:175pt;
  padding:6pt !important;
  vertical-align:middle !important;
}
.exercise-scheme-image{
  width:auto !important;
  height:auto !important;
  max-width:100% !important;
  max-height:162pt !important;
}
.empty-scheme{color:#7A837D;font-size:9pt;}
.exercise-details{padding:0 !important;}
.exercise-metrics{margin:0 !important;}
.exercise-metrics th,.exercise-metrics td{
  text-align:center;
  vertical-align:middle !important;
  font-size:8.2pt;
  padding:3pt 2pt;
  height:31pt;
}
.exercise-text-block{margin:0 !important;}
.exercise-text-block td{height:55pt;font-size:8.8pt;padding:4pt;}
.plan-signature{margin:8pt 0 0 0 !important;}
.plan-signature td{height:28pt;}
img{max-width:100%;height:auto;}
</style>
</head>
<body>
<div class="Section1">
${_docBodyHtml()}
</div>
</body>
</html>''';
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(html)];
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }


  Future<List<pw.Widget>> _trainingPlanPdfWidgets(
    Map<String, dynamic> plan,
    pw.Font regular,
    pw.Font bold,
  ) async {
    String g(String key) => '${plan[key] ?? ''}'.trim();
    const bw = .7;
    pw.Widget cell(String value, {bool isBold = false, pw.Alignment alignment = pw.Alignment.topLeft, double pad = 5}) => pw.Container(
      padding: pw.EdgeInsets.all(pad),
      alignment: alignment,
      child: pw.Text(value.isEmpty ? ' ' : value, style: pw.TextStyle(font: isBold ? bold : regular, fontSize: 8.5)),
    );
    pw.Widget labelValue(String label, String value) => pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8.3)),
        pw.SizedBox(height: 2),
        pw.Text(value.isEmpty ? ' ' : value, style: pw.TextStyle(font: regular, fontSize: 8.3)),
      ]),
    );

    Uint8List? logoBytes;
    final logoHidden = plan['team_logo_hidden'] == true;
    if (!logoHidden) {
      logoBytes =
          _decodeTrainingPlanLogoData('${plan['team_logo_data'] ?? ''}');
      if (logoBytes == null || logoBytes!.isEmpty) {
        final logoUrl =
            _normalizeTrainingPlanLogoUrl(plan['team_logo_url']);
        if (logoUrl.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(logoUrl));
            if (response.statusCode == 200 &&
                response.bodyBytes.isNotEmpty) {
              logoBytes = response.bodyBytes;
            }
          } catch (_) {}
        }
      }
    }

    final widgets = <pw.Widget>[];
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(width: bw, color: PdfColors.black),
        columnWidths: {
          0: const pw.FixedColumnWidth(118),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(children: [
            pw.Container(
              height: 132,
              padding: const pw.EdgeInsets.all(12),
              alignment: pw.Alignment.center,
              child: logoHidden
                  ? pw.SizedBox()
                  : (logoBytes != null && logoBytes!.isNotEmpty
                      ? pw.Center(
                          child: pw.SizedBox(
                            width: 82,
                            height: 96,
                            child: pw.Image(
                              pw.MemoryImage(logoBytes!),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        )
                      : pw.Text(
                          'SPORTOTEKA',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: bold, fontSize: 8.5),
                        )),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                alignment: pw.Alignment.center,
                child: pw.Column(children: [
                  pw.Text('Недельный цикл ${g('cycle')}', style: pw.TextStyle(font: bold, fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('Дата: ${g('date')}', style: pw.TextStyle(font: regular, fontSize: 8.5)),
                ]),
              ),
              pw.Table(
                border: pw.TableBorder.all(width: bw, color: PdfColors.black),
                children: [
                  pw.TableRow(children: [labelValue('Клуб:', g('club')), labelValue('Тренеры:', g('trainers')), labelValue('Команда:', g('team'))]),
                  pw.TableRow(children: [labelValue('Место проведения:', g('location')), labelValue('К-во игроков:', g('players_count')), labelValue('Продолжительность:', '${g('duration_min')} мин.')]),
                  pw.TableRow(children: [labelValue('Тема:', g('theme')), pw.Container(), pw.Container()]),
                ],
              ),
            ]),
          ]),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(width: bw, color: PdfColors.black),
        columnWidths: {0: const pw.FixedColumnWidth(72), 1: const pw.FlexColumnWidth(1)},
        children: [pw.TableRow(children: [
          cell('Цели:', isBold: true, alignment: pw.Alignment.center),
          pw.Table(border: pw.TableBorder.all(width: bw, color: PdfColors.black), children: [
            pw.TableRow(children: [for (final l in const ['Техника','Тактика','Фитнес','Ментальность']) cell(l, isBold: true, alignment: pw.Alignment.center)]),
            pw.TableRow(children: [cell(g('goal_tech')), cell(g('goal_tact')), cell(g('goal_fit')), cell(g('goal_ment'))]),
          ]),
        ])],
      ),
    );
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(width: bw, color: PdfColors.black),
        columnWidths: {0: const pw.FixedColumnWidth(92), 1: const pw.FlexColumnWidth(1)},
        children: [pw.TableRow(children: [cell('Инвентарь:', isBold: true), cell(g('equipment'))])],
      ),
    );

    final exercises = _trainingPlanExercises(plan);
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      String eg(String key) => '${e[key] ?? ''}'.trim();
      Uint8List? schemeBytes;
      final schemes = e['schemes'];
      if (schemes is List && schemes.isNotEmpty && schemes.first is Map) {
        final url = _trainingGraphicAbsoluteUrl('${(schemes.first as Map)['preview_url'] ?? (schemes.first as Map)['preview'] ?? ''}');
        if (url.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) schemeBytes = response.bodyBytes;
          } catch (_) {}
        }
      }
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: bw, color: PdfColors.black)),
          child: pw.Column(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Row(children: [
                pw.Text('${i + 1}. ${eg('title').isEmpty ? 'Упражнение' : eg('title')}', style: pw.TextStyle(font: bold, fontSize: 9)),
                pw.Spacer(),
                pw.Text('Продолжительность: ${eg('duration_min')} мин.', style: pw.TextStyle(font: bold, fontSize: 9)),
              ]),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.SizedBox(
                height: 170,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Container(
                        height: 170,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            width: bw,
                            color: PdfColors.black,
                          ),
                        ),
                        alignment: pw.Alignment.center,
                        child: schemeBytes == null
                            ? pw.Text(
                                'Схема не прикреплена',
                                style: pw.TextStyle(
                                  font: regular,
                                  fontSize: 8.5,
                                ),
                              )
                            : pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Image(
                                  pw.MemoryImage(schemeBytes),
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                      ),
                    ),
                    pw.SizedBox(width: 7),
                    pw.Expanded(
                      flex: 5,
                      child: pw.SizedBox(
                        height: 170,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Table(
                              border: pw.TableBorder.all(
                                width: bw,
                                color: PdfColors.black,
                              ),
                              children: [
                                pw.TableRow(
                                  children: [
                                    for (final l in const [
                                      'Интенсивность',
                                      'К-во\nповторений',
                                      'Время\nработы',
                                      'Пауза'
                                    ])
                                      cell(
                                        l,
                                        isBold: true,
                                        alignment: pw.Alignment.center,
                                        pad: 3,
                                      ),
                                  ],
                                ),
                                pw.TableRow(
                                  children: [
                                    cell(
                                      eg('intensity'),
                                      alignment: pw.Alignment.center,
                                    ),
                                    cell(
                                      eg('repetitions'),
                                      alignment: pw.Alignment.center,
                                    ),
                                    cell(
                                      eg('work_time'),
                                      alignment: pw.Alignment.center,
                                    ),
                                    cell(
                                      eg('pause_time'),
                                      alignment: pw.Alignment.center,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 5),
                            pw.Container(
                              height: 55,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  width: bw,
                                  color: PdfColors.black,
                                ),
                              ),
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Организация:',
                                    style: pw.TextStyle(
                                      font: bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    eg('organization'),
                                    maxLines: 4,
                                    style: pw.TextStyle(
                                      font: regular,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Container(
                              height: 55,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  width: bw,
                                  color: PdfColors.black,
                                ),
                              ),
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Тренерский акцент:',
                                    style: pw.TextStyle(
                                      font: bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    eg('coach_focus'),
                                    maxLines: 4,
                                    style: pw.TextStyle(
                                      font: regular,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    }
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(width: bw, color: PdfColors.black),
        children: [pw.TableRow(children: [labelValue('План-конспект составил', g('signed_role')), cell(g('signed_by'), isBold: true, alignment: pw.Alignment.centerRight)])],
      ),
    );
    return widgets;
  }

  Future<File> _createPdfFile({String? outputPath}) async {
    final title = _titleController.text.trim().isEmpty
        ? 'Документ Sportoteka'
        : _titleController.text.trim();
    final regularData =
        await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final contentWidgets = <pw.Widget>[];
    final plainBuffer = StringBuffer();
    Future<void> flushPlain() async {
      final plain = _exportPlainText(plainBuffer.toString()).trim();
      if (plain.isNotEmpty) {
        contentWidgets.add(pw.Text(plain, style: pw.TextStyle(font: regular, fontSize: 10.5, lineSpacing: 4)));
      }
      plainBuffer.clear();
    }
    for (final line in _bodyController.text.split('\n')) {
      final plan = _decodeTrainingPlanToken(line);
      if (plan == null) {
        plainBuffer.writeln(line);
        continue;
      }
      await flushPlain();
      contentWidgets.addAll(await _trainingPlanPdfWidgets(plan, regular, bold));
    }
    await flushPlain();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: pw.TextStyle(
              font: regular,
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (_) => contentWidgets.isEmpty
            ? <pw.Widget>[pw.SizedBox()]
            : contentWidgets,
      ),
    );
    final String path;
    if (outputPath != null && outputPath.trim().isNotEmpty) {
      path = _ensureExportExtension(outputPath, 'pdf');
    } else {
      final dir = await _shareExportDirectory();
      path = '${dir.path}${Platform.pathSeparator}${_exportFileName('pdf')}';
    }
    final file = File(path);
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }


  Future<void> _showExportSavedDialog({
    required String format,
    required File file,
  }) async {
    if (!mounted) return;
    final path = file.path;
    final folder = file.parent.path;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '$format сохранён',
          style: AppTypography.sectionTitle(color: _text),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Папка:',
                style: AppTypography.captionMedium(color: _muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                folder,
                style: AppTypography.body(color: _text),
              ),
              const SizedBox(height: 12),
              Text(
                'Файл:',
                style: AppTypography.captionMedium(color: _muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                path,
                style: AppTypography.body(color: _text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Путь скопирован')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Скопировать путь'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDoc({bool share = false}) async {
    try {
      String? outputPath;
      if (!share) {
        outputPath = await _chooseExportPath(
          extension: 'doc',
          dialogTitle: 'Сохранить документ Word',
        );
        if (outputPath == null || outputPath.trim().isEmpty) return;
      }
      final file = await _createDocFile(outputPath: outputPath);
      if (share) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/msword')],
          subject: _titleController.text.trim().isEmpty
              ? 'Документ Sportoteka'
              : _titleController.text.trim(),
        );
      } else {
        await _showExportSavedDialog(
          format: 'DOC',
          file: file,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать DOC: $e')),
      );
    }
  }

  Future<void> _exportPdf({bool share = false}) async {
    try {
      String? outputPath;
      if (!share) {
        outputPath = await _chooseExportPath(
          extension: 'pdf',
          dialogTitle: 'Сохранить PDF',
        );
        if (outputPath == null || outputPath.trim().isEmpty) return;
      }
      final file = await _createPdfFile(outputPath: outputPath);
      if (share) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: _titleController.text.trim().isEmpty
              ? 'Документ Sportoteka'
              : _titleController.text.trim(),
        );
      } else {
        await _showExportSavedDialog(
          format: 'PDF',
          file: file,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать PDF: $e')),
      );
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

  TextEditingController get _editingController =>
      _visualMode && _visualBlockController != null
          ? _visualBlockController!
          : _bodyController;

  FocusNode get _editingFocus =>
      _visualMode && _visualBlockFocus != null ? _visualBlockFocus! : _bodyFocus;

  void _focusEditing() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editingFocus.requestFocus();
    });
  }

  void _syncVisualBlock() {
    final controller = _visualBlockController;
    final start = _activeVisualBlockStart;
    final end = _activeVisualBlockEnd;
    if (controller == null || start == null || end == null) return;
    final body = _bodyController.text;
    if (start < 0 || start > body.length || end < start || end > body.length) {
      return;
    }
    final replacement = controller.text;
    final next = body.replaceRange(start, end, replacement);
    final local = controller.selection.isValid
        ? controller.selection.extentOffset.clamp(0, replacement.length).toInt()
        : replacement.length;
    _activeVisualBlockEnd = start + replacement.length;
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + local),
    );
  }

  void _syncVisualBlockIfNeeded() {
    if (_visualMode && _visualBlockController != null) _syncVisualBlock();
  }

  void _finishVisualBlockEditing({bool rebuild = true}) {
    final controller = _visualBlockController;
    if (controller != null) {
      controller.removeListener(_syncVisualBlock);
      controller.dispose();
    }
    _visualBlockFocus?.dispose();
    _visualBlockController = null;
    _visualBlockFocus = null;
    _activeVisualBlockStart = null;
    _activeVisualBlockEnd = null;
    if (rebuild && mounted) setState(() {});
  }

  void _startVisualBlockEditing(_WorkspaceDocBlock block) {
    if (widget.readOnly || block.kind == _WorkspaceDocBlockKind.image ||
        block.kind == _WorkspaceDocBlockKind.rule ||
        block.kind == _WorkspaceDocBlockKind.table) {
      return;
    }
    _finishVisualBlockEditing(rebuild: false);
    final controller = _WorkspaceRichTextController(text: block.raw);
    final focus = FocusNode();
    _visualBlockController = controller;
    _visualBlockFocus = focus;
    _activeVisualBlockStart = block.start;
    _activeVisualBlockEnd = block.end;
    _selectedImageStart = null;
    controller.addListener(_syncVisualBlock);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    });
  }

  void _setVisualMode(bool value) {
    if (_visualMode == value) return;
    _finishVisualBlockEditing(rebuild: false);
    _selectedImageStart = null;
    setState(() => _visualMode = value);
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bodyFocus.requestFocus();
      });
    }
  }

  bool _ensureVisualFormattingTarget() {
    if (!_visualMode || _visualBlockController != null) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала нажмите на абзац, который хотите отформатировать'),
          duration: Duration(milliseconds: 1400),
        ),
      );
    }
    return false;
  }

  void _wrapSelection(String left, String right) {
    if (widget.readOnly || !_ensureVisualFormattingTarget()) return;
    final controller = _editingController;
    final value = controller.value;
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
    final cursor =
        selected.isEmpty ? start + left.length : start + replacement.length;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  void _prefixSelection(String prefix) {
    if (widget.readOnly || !_ensureVisualFormattingTarget()) return;
    final controller = _editingController;
    final value = controller.value;
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
    controller.value = TextEditingValue(
      text: value.text.replaceRange(lineStart, lineEnd, replacement),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  void _replaceBodySelection(String replacement, {bool selectReplacement = false}) {
    if (widget.readOnly) return;
    final controller = _editingController;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, value.text.length).toInt()
        : value.text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, value.text.length).toInt()
        : start;
    final next = value.text.replaceRange(start, end, replacement);
    final newSelection = selectReplacement
        ? TextSelection(baseOffset: start, extentOffset: start + replacement.length)
        : TextSelection.collapsed(offset: start + replacement.length);
    controller.value = TextEditingValue(text: next, selection: newSelection);
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  Future<void> _copySelection() async {
    final controller = _editingController;
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      await _copyDocument();
      return;
    }
    final start = selection.start.clamp(0, value.text.length).toInt();
    final end = selection.end.clamp(start, value.text.length).toInt();
    await Clipboard.setData(ClipboardData(text: value.text.substring(start, end)));
  }

  Future<void> _cutSelection() async {
    if (widget.readOnly) return;
    final controller = _editingController;
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start.clamp(0, value.text.length).toInt();
    final end = selection.end.clamp(start, value.text.length).toInt();
    await Clipboard.setData(ClipboardData(text: value.text.substring(start, end)));
    controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  Future<void> _pasteClipboard() async {
    if (widget.readOnly) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    _replaceBodySelection(text);
  }

  void _selectAllBody() {
    if (_editingController.text.isEmpty) return;
    _editingController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _editingController.text.length,
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  void _duplicateSelection() {
    if (widget.readOnly) return;
    final controller = _editingController;
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start.clamp(0, value.text.length).toInt();
    final end = selection.end.clamp(start, value.text.length).toInt();
    final selected = value.text.substring(start, end);
    controller.value = TextEditingValue(
      text: value.text.replaceRange(end, end, selected),
      selection: TextSelection(baseOffset: end, extentOffset: end + selected.length),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  void _insertHorizontalRule() {
    _replaceBodySelection('\n---\n');
    if (_visualMode) _finishVisualBlockEditing();
  }

  void _insertDateTime() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _replaceBodySelection(
      '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}',
    );
  }

  void _insertTable() {
    _replaceBodySelection(
      '\n| Столбец 1 | Столбец 2 | Столбец 3 |\n'
      '| --- | --- | --- |\n'
      '|  |  |  |\n'
      '|  |  |  |\n',
    );
    if (_visualMode) _finishVisualBlockEditing();
  }

  Future<String?> _askText({required String title, required String hint}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: AppTypography.sectionTitle(color: _text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Вставить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }

  Future<void> _insertLink() async {
    if (widget.readOnly) return;
    final controller = _editingController;
    final value = controller.value;
    final selection = value.selection;
    final selected = selection.isValid && !selection.isCollapsed
        ? value.text.substring(selection.start, selection.end)
        : '';
    final url = await _askText(title: 'Вставить ссылку', hint: 'https://…');
    if (url == null || url.isEmpty) return;
    final label = selected.trim().isEmpty ? 'Ссылка' : selected.trim();
    _replaceBodySelection('[$label]($url)');
  }

  Future<void> _insertImage() async {
    if (widget.readOnly) return;
    String? url;

    if (widget.onUploadImage != null) {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path != null && path.trim().isNotEmpty) {
        try {
          url = await widget.onUploadImage!(path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось загрузить изображение: $e')),
            );
          }
          return;
        }
      }
    }

    url ??= await _askText(
      title: 'Вставить изображение',
      hint: 'Ссылка на изображение https://…',
    );
    if (url == null || url.trim().isEmpty) return;
    final caption = await _askText(
      title: 'Подпись к изображению',
      hint: 'Необязательно',
    );
    final safeCaption = (caption ?? '').replaceAll(']', '').trim();
    _replaceBodySelection(
      '\n![${safeCaption.isEmpty ? 'Изображение' : safeCaption}](${url.trim()}){width=100%}\n',
    );
  }

  void _resizeNearestImage(int deltaPercent) {
    if (widget.readOnly) return;
    if (_visualMode && _selectedImageStart != null) {
      for (final block in _parseDocumentBlocks()) {
        if (block.start == _selectedImageStart && block.image != null) {
          _resizeVisualImage(block, deltaPercent);
          return;
        }
      }
    }
    final controller = _editingController;
    final value = controller.value;
    final cursor = value.selection.isValid ? value.selection.extentOffset : value.text.length;
    final regex = RegExp(
      r'!\[[^\]]*\]\([^\)]+\)\{width=(\d+)%(?:;align=(?:left|center|right))?\}',
    );
    RegExpMatch? best;
    for (final match in regex.allMatches(value.text)) {
      if (match.start <= cursor) best = match;
      if (match.start > cursor && best == null) {
        best = match;
        break;
      }
    }
    if (best == null) return;
    final current = int.tryParse(best.group(1) ?? '') ?? 100;
    final nextWidth = (current + deltaPercent).clamp(20, 100);
    final matched = best.group(0)!;
    final replaced = matched.replaceFirst('width=$current%', 'width=$nextWidth%');
    controller.value = TextEditingValue(
      text: value.text.replaceRange(best.start, best.end, replaced),
      selection: TextSelection.collapsed(offset: best.start + replaced.length),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  void _applyFontSize(int size) {
    _wrapSelection('<fs:$size>', '</fs>');
  }

  void _applyTextColor(String hex) {
    _wrapSelection('<c:$hex>', '</c>');
  }

  void _applyHighlight(String hex) {
    _wrapSelection('<bg:$hex>', '</bg>');
  }

  void _applyAlignment(String alignment) {
    if (widget.readOnly || !_ensureVisualFormattingTarget()) return;
    final controller = _editingController;
    final value = controller.value;
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
    final raw = value.text.substring(lineStart, lineEnd);
    final cleaned = raw
        .split('\n')
        .map((line) => line.replaceFirst(
            RegExp(r'^<align:(left|center|right|justify)>'), ''))
        .toList();
    final replacement = cleaned
        .map((line) => alignment == 'left' ? line : '<align:$alignment>$line')
        .join('\n');
    controller.value = TextEditingValue(
      text: value.text.replaceRange(lineStart, lineEnd, replacement),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + replacement.length,
      ),
    );
    _syncVisualBlockIfNeeded();
    _focusEditing();
  }

  List<_WorkspaceDocBlock> _parseDocumentBlocks() {
    final text = _bodyController.text;
    if (text.isEmpty) return <_WorkspaceDocBlock>[];
    final blocks = <_WorkspaceDocBlock>[];
    final lines = <_WorkspaceDocLine>[];
    var offset = 0;
    final rawLines = text.split('\n');
    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      lines.add(_WorkspaceDocLine(
        text: line,
        start: offset,
        end: offset + line.length,
      ));
      offset += line.length;
      if (i < rawLines.length - 1) offset += 1;
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.text.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        var j = i + 1;
        while (j < lines.length) {
          final candidate = lines[j].text.trim();
          if (!(candidate.startsWith('|') && candidate.endsWith('|'))) break;
          j++;
        }
        if (j - i >= 2) {
          final end = lines[j - 1].end;
          blocks.add(_WorkspaceDocBlock(
            kind: _WorkspaceDocBlockKind.table,
            start: line.start,
            end: end,
            raw: text.substring(line.start, end),
          ));
          i = j;
          continue;
        }
      }

      final image = _WorkspaceVisualImageData.tryParse(line.text);
      if (image != null) {
        blocks.add(_WorkspaceDocBlock(
          kind: _WorkspaceDocBlockKind.image,
          start: line.start,
          end: line.end,
          raw: line.text,
          image: image,
        ));
      } else if (trimmed == '---') {
        blocks.add(_WorkspaceDocBlock(
          kind: _WorkspaceDocBlockKind.rule,
          start: line.start,
          end: line.end,
          raw: line.text,
        ));
      } else if (trimmed.isEmpty) {
        blocks.add(_WorkspaceDocBlock(
          kind: _WorkspaceDocBlockKind.spacer,
          start: line.start,
          end: line.end,
          raw: line.text,
        ));
      } else {
        blocks.add(_WorkspaceDocBlock(
          kind: _WorkspaceDocBlockKind.text,
          start: line.start,
          end: line.end,
          raw: line.text,
        ));
      }
      i++;
    }
    return blocks;
  }

  void _editRawBlock(_WorkspaceDocBlock block) {
    _setVisualMode(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final len = _bodyController.text.length;
      _bodyController.selection = TextSelection(
        baseOffset: block.start.clamp(0, len).toInt(),
        extentOffset: block.end.clamp(0, len).toInt(),
      );
      _bodyFocus.requestFocus();
    });
  }

  void _replaceCanonicalRange(int start, int end, String replacement) {
    if (widget.readOnly) return;
    final value = _bodyController.value;
    if (start < 0 || start > value.text.length || end < start || end > value.text.length) {
      return;
    }
    _finishVisualBlockEditing(rebuild: false);
    final next = value.text.replaceRange(start, end, replacement);
    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _updateVisualImage(
    _WorkspaceDocBlock block, {
    int? width,
    String? alignment,
    String? caption,
  }) {
    final image = block.image;
    if (image == null) return;
    final next = image.copyWith(
      widthPercent: width ?? image.widthPercent,
      alignment: alignment ?? image.alignment,
      caption: caption ?? image.caption,
    );
    _selectedImageStart = block.start;
    _replaceCanonicalRange(block.start, block.end, next.toMarkup());
    if (mounted) setState(() {});
  }

  void _resizeVisualImage(_WorkspaceDocBlock block, int deltaPercent) {
    final image = block.image;
    if (image == null) return;
    final width = (image.widthPercent + deltaPercent).clamp(20, 100).toInt();
    _updateVisualImage(block, width: width);
  }

  void _deleteVisualBlock(_WorkspaceDocBlock block) {
    var start = block.start;
    var end = block.end;
    final body = _bodyController.text;
    if (end < body.length && body.substring(end, end + 1) == '\n') {
      end += 1;
    } else if (start > 0 && body.substring(start - 1, start) == '\n') {
      start -= 1;
    }
    _selectedImageStart = null;
    _selectedTableStart = null;
    _replaceCanonicalRange(start, end, '');
  }

  Future<void> _copyVisualBlock(_WorkspaceDocBlock block) async {
    await Clipboard.setData(ClipboardData(text: block.raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Объект скопирован')),
    );
  }

  Future<void> _cutVisualBlock(_WorkspaceDocBlock block) async {
    if (widget.readOnly) return;
    await Clipboard.setData(ClipboardData(text: block.raw));
    _deleteVisualBlock(block);
  }

  void _duplicateVisualBlock(_WorkspaceDocBlock block) {
    if (widget.readOnly) return;
    final body = _bodyController.text;
    var insertAt = block.end.clamp(0, body.length).toInt();
    final needsLeadingBreak = insertAt > 0 &&
        body.substring(insertAt - 1, insertAt) != '\n';
    final needsTrailingBreak = insertAt < body.length &&
        body.substring(insertAt, insertAt + 1) != '\n';
    final insertion =
        '${needsLeadingBreak ? '\n' : ''}${block.raw}${needsTrailingBreak ? '\n' : ''}';
    _replaceCanonicalRange(insertAt, insertAt, insertion);
  }

  int _lineIndexForOffset(String text, int offset) {
    final safe = offset.clamp(0, text.length).toInt();
    if (safe == 0) return 0;
    return '\n'.allMatches(text.substring(0, safe)).length;
  }

  void _moveImageBlock(int sourceStart, int? targetStart) {
    if (widget.readOnly) return;
    final body = _bodyController.text;
    final blocks = _parseDocumentBlocks();
    _WorkspaceDocBlock? source;
    for (final block in blocks) {
      if (block.start == sourceStart &&
          block.kind == _WorkspaceDocBlockKind.image) {
        source = block;
        break;
      }
    }
    if (source == null) return;

    final sourceLine = _lineIndexForOffset(body, source.start);
    var targetLine = targetStart == null
        ? body.split('\n').length
        : _lineIndexForOffset(body, targetStart);
    if (targetLine == sourceLine || targetLine == sourceLine + 1) return;

    final lines = body.split('\n');
    if (sourceLine < 0 || sourceLine >= lines.length) return;
    final movedLine = lines.removeAt(sourceLine);
    if (sourceLine < targetLine) targetLine -= 1;
    targetLine = targetLine.clamp(0, lines.length).toInt();
    lines.insert(targetLine, movedLine);

    _finishVisualBlockEditing(rebuild: false);
    _selectedImageStart = null;
    _bodyController.value = TextEditingValue(
      text: lines.join('\n'),
      selection: TextSelection.collapsed(
        offset: lines.take(targetLine + 1).join('\n').length,
      ),
    );
  }

  Widget _buildBlockDropTarget(int? targetStart) {
    if (widget.readOnly) return const SizedBox(height: 3);
    return DragTarget<int>(
      onWillAccept: (sourceStart) => sourceStart != null && sourceStart != targetStart,
      onAccept: (sourceStart) => _moveImageBlock(sourceStart, targetStart),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 16 : 4,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE5F4EC) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: active
                ? Border.all(color: _green.withOpacity(.45), width: 1)
                : null,
          ),
        );
      },
    );
  }

  List<List<String>> _visualTableRows(_WorkspaceDocBlock block) {
    final parsed = block.raw
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line
            .trim()
            .replaceFirst(RegExp(r'^\|'), '')
            .replaceFirst(RegExp(r'\|$'), '')
            .split('|')
            .map((cell) => cell.trim())
            .toList())
        .toList();
    if (parsed.length >= 2 &&
        parsed[1].every((cell) => RegExp(r'^:?-{2,}:?$').hasMatch(cell))) {
      return <List<String>>[parsed.first, ...parsed.skip(2)];
    }
    return parsed;
  }

  String _tableMarkup(List<List<String>> rows) {
    if (rows.isEmpty) rows = <List<String>>[<String>['']];
    var columns = 1;
    for (final row in rows) {
      if (row.length > columns) columns = row.length;
    }
    final normalized = rows
        .map((row) => List<String>.generate(
              columns,
              (index) => index < row.length
                  ? row[index].replaceAll('|', '¦').replaceAll('\n', ' ')
                  : '',
            ))
        .toList();
    final out = <String>[];
    out.add('| ${normalized.first.join(' | ')} |');
    out.add('| ${List<String>.filled(columns, '---').join(' | ')} |');
    for (final row in normalized.skip(1)) {
      out.add('| ${row.join(' | ')} |');
    }
    return out.join('\n');
  }

  void _replaceVisualTable(_WorkspaceDocBlock block, List<List<String>> rows) {
    if (widget.readOnly) return;
    _selectedTableStart = block.start;
    _replaceCanonicalRange(block.start, block.end, _tableMarkup(rows));
    if (mounted) setState(() {});
  }

  void _addVisualTableRow(_WorkspaceDocBlock block) {
    final rows = _visualTableRows(block);
    var columns = 1;
    for (final row in rows) {
      if (row.length > columns) columns = row.length;
    }
    rows.add(List<String>.filled(columns, ''));
    _replaceVisualTable(block, rows);
  }

  void _removeVisualTableRow(_WorkspaceDocBlock block) {
    final rows = _visualTableRows(block);
    if (rows.length <= 1) return;
    rows.removeLast();
    _replaceVisualTable(block, rows);
  }

  void _addVisualTableColumn(_WorkspaceDocBlock block) {
    final rows = _visualTableRows(block);
    if (rows.isEmpty) rows.add(<String>['']);
    for (final row in rows) {
      row.add('');
    }
    _replaceVisualTable(block, rows);
  }

  void _removeVisualTableColumn(_WorkspaceDocBlock block) {
    final rows = _visualTableRows(block);
    var columns = 0;
    for (final row in rows) {
      if (row.length > columns) columns = row.length;
    }
    if (columns <= 1) return;
    for (final row in rows) {
      if (row.isNotEmpty) row.removeLast();
    }
    _replaceVisualTable(block, rows);
  }

  void _updateVisualTableCell(
    _WorkspaceDocBlock block,
    int rowIndex,
    int columnIndex,
    String value,
  ) {
    final rows = _visualTableRows(block);
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    while (rows[rowIndex].length <= columnIndex) {
      rows[rowIndex].add('');
    }
    rows[rowIndex][columnIndex] = value;
    _replaceVisualTable(block, rows);
  }

  RelativeRect _menuPosition(Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _showBlockContextMenu(
    _WorkspaceDocBlock block,
    Offset globalPosition,
  ) async {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'copy', child: Text('Копировать')),
      if (!widget.readOnly)
        const PopupMenuItem(value: 'cut', child: Text('Вырезать')),
      if (!widget.readOnly)
        const PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
    ];

    if (!widget.readOnly && block.kind == _WorkspaceDocBlockKind.image) {
      items.add(const PopupMenuDivider());
      items.addAll(const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'image_caption', child: Text('Подпись к изображению')),
        PopupMenuItem(value: 'image_left', child: Text('Изображение слева')),
        PopupMenuItem(value: 'image_center', child: Text('Изображение по центру')),
        PopupMenuItem(value: 'image_right', child: Text('Изображение справа')),
      ]);
    }
    if (!widget.readOnly && block.kind == _WorkspaceDocBlockKind.table) {
      items.add(const PopupMenuDivider());
      items.addAll(const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'table_add_row', child: Text('Добавить строку')),
        PopupMenuItem(value: 'table_remove_row', child: Text('Удалить последнюю строку')),
        PopupMenuItem(value: 'table_add_column', child: Text('Добавить столбец')),
        PopupMenuItem(value: 'table_remove_column', child: Text('Удалить последний столбец')),
      ]);
    }
    if (!widget.readOnly && block.kind == _WorkspaceDocBlockKind.text) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(value: 'edit', child: Text('Редактировать абзац')));
    }
    if (!widget.readOnly) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Text('Удалить', style: TextStyle(color: Color(0xFFB42318))),
      ));
    }

    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(globalPosition),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: items,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'copy':
        await _copyVisualBlock(block);
        break;
      case 'cut':
        await _cutVisualBlock(block);
        break;
      case 'duplicate':
        _duplicateVisualBlock(block);
        break;
      case 'delete':
        _deleteVisualBlock(block);
        break;
      case 'edit':
        _startVisualBlockEditing(block);
        break;
      case 'image_caption':
        setState(() => _selectedImageStart = block.start);
        break;
      case 'image_left':
        _updateVisualImage(block, alignment: 'left');
        break;
      case 'image_center':
        _updateVisualImage(block, alignment: 'center');
        break;
      case 'image_right':
        _updateVisualImage(block, alignment: 'right');
        break;
      case 'table_add_row':
        _addVisualTableRow(block);
        break;
      case 'table_remove_row':
        _removeVisualTableRow(block);
        break;
      case 'table_add_column':
        _addVisualTableColumn(block);
        break;
      case 'table_remove_column':
        _removeVisualTableColumn(block);
        break;
    }
  }

  Widget _buildVisualDocument({required bool compact}) {
    final blocks = _parseDocumentBlocks();
    if (blocks.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.readOnly
            ? null
            : () {
                _setVisualMode(false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _bodyFocus.requestFocus();
                });
              },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 320 : 430),
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.readOnly
                ? 'Документ пуст'
                : 'Нажмите здесь и начните писать…',
            style: AppTypography.body(color: const Color(0xFFA2ABA5)).copyWith(
              fontSize: compact ? 14 : 15,
              height: 1.62,
            ),
          ),
        ),
      );
    }

    final widgets = <Widget>[];
    for (final block in blocks) {
      widgets.add(_buildBlockDropTarget(block.start));
      final activeStart = _activeVisualBlockStart;
      final activeEnd = _activeVisualBlockEnd;
      if (activeStart != null && activeEnd != null) {
        if (block.start > activeStart && block.start < activeEnd) continue;
        if (block.start == activeStart && _visualBlockController != null) {
          widgets.add(_buildActiveVisualTextBlock(compact: compact));
          continue;
        }
      }
      switch (block.kind) {
        case _WorkspaceDocBlockKind.spacer:
          widgets.add(const SizedBox(height: 11));
          break;
        case _WorkspaceDocBlockKind.rule:
          widgets.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _line),
          ));
          break;
        case _WorkspaceDocBlockKind.image:
          widgets.add(_buildVisualImage(block, compact: compact));
          break;
        case _WorkspaceDocBlockKind.table:
          widgets.add(_buildVisualTable(block, compact: compact));
          break;
        case _WorkspaceDocBlockKind.text:
          widgets.add(_buildVisualTextBlock(block, compact: compact));
          break;
      }
    }
    widgets.add(_buildBlockDropTarget(null));
    widgets.add(
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            _showDocumentContextMenu(details.globalPosition),
        onTap: widget.readOnly
            ? null
            : () {
                _setVisualMode(false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _bodyController.selection = TextSelection.collapsed(
                    offset: _bodyController.text.length,
                  );
                  _bodyFocus.requestFocus();
                });
              },
        child: SizedBox(height: compact ? 120 : 180),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildActiveVisualTextBlock({required bool compact}) {
    final controller = _visualBlockController!;
    final focus = _visualBlockFocus!;
    final styleInfo = _WorkspaceTextBlockStyle.parse(controller.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focus,
        readOnly: widget.readOnly,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textAlign: styleInfo.textAlign,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 3),
        ),
        style: styleInfo.baseStyle(
          compact: compact,
          color: _text,
        ),
        onTapOutside: (_) => _finishVisualBlockEditing(),
      ),
    );
  }

  Widget _buildVisualTextBlock(
    _WorkspaceDocBlock block, {
    required bool compact,
  }) {
    final trainingPlan = _decodeTrainingPlanToken(block.raw);
    if (trainingPlan != null) {
      return _buildTrainingPlanVisualTemplate(
        block,
        trainingPlan,
        compact: compact,
      );
    }
    final info = _WorkspaceTextBlockStyle.parse(block.raw);
    final text = info.content;
    final span = _workspaceRichSpan(
      text,
      info.baseStyle(compact: compact, color: _text),
    );
    Widget child = RichText(
      textAlign: info.textAlign,
      text: span,
    );
    if (info.quote) {
      child = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8F6),
          borderRadius: BorderRadius.circular(9),
          border: const Border(left: BorderSide(color: _green, width: 3)),
        ),
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          _showBlockContextMenu(block, details.globalPosition),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.readOnly ? null : () => _startVisualBlockEditing(block),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: info.headingLevel > 0 ? 6 : 3),
          child: child,
        ),
      ),
    );
  }


  Widget _trainingPlanCell({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool multiline = false,
    bool centered = false,
    double minHeight = 52,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      alignment: centered ? Alignment.center : Alignment.topLeft,
      child: Column(
        mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            style: AppTypography.captionMedium(color: _text).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 10.8,
            ),
          ),
          const SizedBox(height: 3),
          _TrainingPlanInlineField(
            value: value,
            readOnly: widget.readOnly,
            multiline: multiline,
            centered: centered,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _trainingPlanPlainField({
    required String value,
    required ValueChanged<String> onChanged,
    bool multiline = false,
    bool centered = false,
    String? hint,
  }) {
    return _TrainingPlanInlineField(
      value: value,
      readOnly: widget.readOnly,
      multiline: multiline,
      centered: centered,
      hint: hint,
      onChanged: onChanged,
    );
  }

  Widget _buildTrainingPlanVisualTemplate(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan, {
    required bool compact,
  }) {
    String field(String key) => '${plan[key] ?? ''}';
    final exercises = _trainingPlanExercises(plan);
    const borderColor = Color(0xFF252A27);
    const borderWidth = .8;

    Widget blackBorder(Widget child) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: child,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'План-конспект тренировки',
            style: AppTypography.sectionTitle(color: _text).copyWith(
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          blackBorder(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: compact ? 72 : 90,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: borderColor, width: borderWidth),
                        ),
                      ),
                      child: _buildTrainingPlanLogo(
                        block,
                        plan,
                        compact: compact,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: borderColor, width: borderWidth),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Недельный цикл ', style: AppTypography.body(color: _text).copyWith(fontWeight: FontWeight.w700, fontSize: 11.5)),
                                    Expanded(
                                      child: _trainingPlanPlainField(
                                        value: field('cycle'),
                                        centered: true,
                                        hint: '___',
                                        onChanged: (v) => _updateTrainingPlanField(block, plan, 'cycle', v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: compact ? 150 : 190,
                                child: Row(
                                  children: [
                                    Text('Дата: ', style: AppTypography.body(color: _text).copyWith(fontSize: 11.5)),
                                    Expanded(
                                      child: _trainingPlanPlainField(
                                        value: field('date'),
                                        centered: true,
                                        hint: 'дд.мм.гггг',
                                        onChanged: (v) => _updateTrainingPlanField(block, plan, 'date', v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Table(
                          border: TableBorder.all(color: borderColor, width: borderWidth),
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(children: [
                              _trainingPlanCell(label: 'Клуб:', value: field('club'), onChanged: (v) => _updateTrainingPlanField(block, plan, 'club', v)),
                              _trainingPlanCell(label: 'Тренеры:', value: field('trainers'), onChanged: (v) => _updateTrainingPlanField(block, plan, 'trainers', v)),
                              _trainingPlanCell(label: 'Команда:', value: field('team'), onChanged: (v) => _updateTrainingPlanField(block, plan, 'team', v)),
                            ]),
                            TableRow(children: [
                              _trainingPlanCell(label: 'Место проведения:', value: field('location'), onChanged: (v) => _updateTrainingPlanField(block, plan, 'location', v)),
                              _trainingPlanCell(label: 'К-во игроков:', value: field('players_count'), centered: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'players_count', v)),
                              _trainingPlanCell(label: 'Продолжительность:', value: field('duration_min'), centered: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'duration_min', v)),
                            ]),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: borderColor, width: borderWidth),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text('Тема:', style: AppTypography.body(color: _text).copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ),
                              Expanded(
                                child: _trainingPlanPlainField(
                                  value: field('theme'),
                                  multiline: false,
                                  onChanged: (v) => _updateTrainingPlanField(block, plan, 'theme', v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          blackBorder(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: compact ? 72 : 90,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: borderWidth),
                      ),
                    ),
                    child: Text('Цели:', style: AppTypography.body(color: _text).copyWith(fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ),
                  Expanded(
                    child: Table(
                      border: TableBorder.all(color: borderColor, width: borderWidth),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF5F6F5)),
                          children: [
                            for (final label in const ['Техника', 'Тактика', 'Фитнес', 'Ментальность'])
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(label, textAlign: TextAlign.center, style: AppTypography.captionMedium(color: _text).copyWith(fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        TableRow(children: [
                          _trainingPlanCell(label: '', value: field('goal_tech'), multiline: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'goal_tech', v), minHeight: 76),
                          _trainingPlanCell(label: '', value: field('goal_tact'), multiline: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'goal_tact', v), minHeight: 76),
                          _trainingPlanCell(label: '', value: field('goal_fit'), multiline: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'goal_fit', v), minHeight: 76),
                          _trainingPlanCell(label: '', value: field('goal_ment'), multiline: true, onChanged: (v) => _updateTrainingPlanField(block, plan, 'goal_ment', v), minHeight: 76),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          blackBorder(
            Row(
              children: [
                Container(
                  width: compact ? 92 : 110,
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: borderColor, width: borderWidth),
                    ),
                  ),
                  child: Text('Инвентарь:', style: AppTypography.body(color: _text).copyWith(fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: _trainingPlanPlainField(
                      value: field('equipment'),
                      multiline: true,
                      onChanged: (v) => _updateTrainingPlanField(block, plan, 'equipment', v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < exercises.length; i++) ...[
            _buildTrainingPlanExerciseVisual(
              block,
              plan,
              exercises[i],
              i,
              compact: compact,
            ),
            const SizedBox(height: 12),
          ],
          if (!widget.readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _appendTrainingPlanExercise(block, plan),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF5EF),
                  foregroundColor: _green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text('Добавить упражнение ${exercises.length + 1}', style: AppTypography.actionStrong(color: _green)),
              ),
            ),
          const SizedBox(height: 14),
          blackBorder(
            Row(
              children: [
                Expanded(
                  child: _trainingPlanCell(
                    label: 'План-конспект составил / должность',
                    value: field('signed_role'),
                    onChanged: (v) => _updateTrainingPlanField(block, plan, 'signed_role', v),
                  ),
                ),
                Expanded(
                  child: _trainingPlanCell(
                    label: 'ФИО',
                    value: field('signed_by'),
                    onChanged: (v) => _updateTrainingPlanField(block, plan, 'signed_by', v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingPlanExerciseVisual(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan,
    Map<String, dynamic> exercise,
    int exerciseIndex, {
    required bool compact,
  }) {
    const borderColor = Color(0xFF252A27);
    const borderWidth = .8;
    String value(String key) => '${exercise[key] ?? ''}';
    final schemes = exercise['schemes'] is List
        ? (exercise['schemes'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final preview = schemes.isEmpty
        ? ''
        : _trainingGraphicAbsoluteUrl('${schemes.first['preview_url'] ?? schemes.first['preview'] ?? ''}');
    final number = exerciseIndex + 1;
    final loading = _trainingPlanSchemeLoading && _trainingPlanSchemeLoadingExercise == exerciseIndex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: borderWidth),
              ),
            ),
            child: Row(
              children: [
                Text('$number. ', style: AppTypography.body(color: _text).copyWith(fontWeight: FontWeight.w800, fontSize: 11.8)),
                Expanded(
                  child: _trainingPlanPlainField(
                    value: value('title'),
                    hint: 'Название упражнения',
                    onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'title', v),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Продолжительность: ', style: AppTypography.captionMedium(color: _text).copyWith(fontWeight: FontWeight.w700)),
                SizedBox(
                  width: 58,
                  child: _trainingPlanPlainField(
                    value: value('duration_min'),
                    centered: true,
                    hint: 'мин.',
                    onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'duration_min', v),
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(width: 5),
                  PopupMenuButton<String>(
                    tooltip: 'Упражнение',
                    onSelected: (action) {
                      switch (action) {
                        case 'scheme':
                          _pickTrainingGraphicForPlanExercise(block, plan, exerciseIndex);
                          break;
                        case 'duplicate':
                          _duplicateTrainingPlanExercise(block, plan, exerciseIndex);
                          break;
                        case 'up':
                          _moveTrainingPlanExercise(block, plan, exerciseIndex, -1);
                          break;
                        case 'down':
                          _moveTrainingPlanExercise(block, plan, exerciseIndex, 1);
                          break;
                        case 'delete':
                          _removeTrainingPlanExercise(block, plan, exerciseIndex);
                          break;
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      const PopupMenuItem(value: 'scheme', child: Text('Добавить / сменить схему')),
                      const PopupMenuItem(value: 'duplicate', child: Text('Дублировать упражнение')),
                      if (exerciseIndex > 0) const PopupMenuItem(value: 'up', child: Text('Переместить выше')),
                      if (exerciseIndex < _trainingPlanExercises(plan).length - 1) const PopupMenuItem(value: 'down', child: Text('Переместить ниже')),
                      if (_trainingPlanExercises(plan).length > 1) const PopupMenuItem(value: 'delete', child: Text('Удалить упражнение')),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded, size: 18, color: _muted),
                  ),
                ],
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    constraints: BoxConstraints(minHeight: compact ? 190 : 230),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: borderWidth),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFBFA),
                                border: Border.all(color: borderColor, width: borderWidth),
                              ),
                              child: preview.isNotEmpty
                                  ? Image.network(
                                      preview,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _trainingPlanSchemeEmptyState(block, plan, exerciseIndex, loading: loading),
                                    )
                                  : _trainingPlanSchemeEmptyState(block, plan, exerciseIndex, loading: loading),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 12,
                          child: Container(
                            color: Colors.white.withOpacity(.88),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            child: Text('Схема / поле', style: AppTypography.captionMedium(color: _text).copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ),
                        if (!widget.readOnly && preview.isNotEmpty)
                          Positioned(
                            right: 14,
                            top: 12,
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              child: InkWell(
                                onTap: loading ? null : () => _pickTrainingGraphicForPlanExercise(block, plan, exerciseIndex),
                                borderRadius: BorderRadius.circular(9),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (loading)
                                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.7, color: _green))
                                      else
                                        const Icon(Icons.add_rounded, size: 16, color: _green),
                                      const SizedBox(width: 4),
                                      Text(schemes.length > 1 ? 'Схемы ${schemes.length}' : 'Схема', style: AppTypography.captionMedium(color: _green).copyWith(fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Table(
                        border: TableBorder.all(color: borderColor, width: borderWidth),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFFF5F6F5)),
                            children: [
                              for (final label in const ['Интенсивность', 'К-во\nповторений', 'Время\nработы', 'Пауза'])
                                Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Text(label, textAlign: TextAlign.center, style: AppTypography.caption(color: _text).copyWith(fontWeight: FontWeight.w800, fontSize: 9.6)),
                                ),
                            ],
                          ),
                          TableRow(children: [
                            _trainingPlanCell(label: '', value: value('intensity'), centered: true, onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'intensity', v), minHeight: 48),
                            _trainingPlanCell(label: '', value: value('repetitions'), centered: true, onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'repetitions', v), minHeight: 48),
                            _trainingPlanCell(label: '', value: value('work_time'), centered: true, onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'work_time', v), minHeight: 48),
                            _trainingPlanCell(label: '', value: value('pause_time'), centered: true, onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'pause_time', v), minHeight: 48),
                          ]),
                        ],
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: borderColor, width: borderWidth),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Организация:', style: AppTypography.captionMedium(color: _text).copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Expanded(
                                child: _trainingPlanPlainField(
                                  value: value('organization'),
                                  multiline: true,
                                  onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'organization', v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: borderColor, width: borderWidth),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Тренерский акцент:', style: AppTypography.captionMedium(color: _text).copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Expanded(
                                child: _trainingPlanPlainField(
                                  value: value('coach_focus'),
                                  multiline: true,
                                  onChanged: (v) => _updateTrainingPlanExerciseField(block, plan, exerciseIndex, 'coach_focus', v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingPlanSchemeEmptyState(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan,
    int exerciseIndex, {
    required bool loading,
  }) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: _green),
            SizedBox(height: 9),
            Text('Загружаю схемы…'),
          ],
        ),
      );
    }
    if (widget.readOnly) {
      return Center(
        child: Text('Схема не прикреплена', style: AppTypography.body(color: _muted)),
      );
    }
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _pickTrainingGraphicForPlanExercise(block, plan, exerciseIndex),
        style: OutlinedButton.styleFrom(
          foregroundColor: _green,
          side: const BorderSide(color: _green, width: .9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Добавить схему'),
      ),
    );
  }

  Future<void> _pickTrainingGraphicForPlanExercise(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan,
    int exerciseIndex,
  ) async {
    if (widget.readOnly || _trainingPlanSchemeLoading) return;

    final clubId = widget.aiClubId ?? 0;
    if (clubId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить клуб для выбора схемы.'),
        ),
      );
      return;
    }

    final currentExercises = _trainingPlanExercises(plan);
    final preselected = <int>[];
    if (exerciseIndex >= 0 && exerciseIndex < currentExercises.length) {
      final rawSchemes = currentExercises[exerciseIndex]['schemes'];
      if (rawSchemes is List) {
        for (final raw in rawSchemes) {
          if (raw is Map) {
            final id = int.tryParse('${raw['id'] ?? 0}') ?? 0;
            if (id > 0 && !preselected.contains(id)) preselected.add(id);
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _sidePickerType = null;
      _trainingGraphicsPickerOpen = true;
      _trainingGraphicsPickerBlock = block;
      _trainingGraphicsPickerPlan = _cloneTrainingPlan(plan);
      _trainingGraphicsPickerExerciseIndex = exerciseIndex;
      _trainingGraphicsPickerPreselected = preselected;
    });
  }

  void _closeTrainingGraphicsPicker() {
    if (!mounted) return;
    setState(() {
      _trainingGraphicsPickerOpen = false;
      _trainingGraphicsPickerBlock = null;
      _trainingGraphicsPickerPlan = null;
      _trainingGraphicsPickerExerciseIndex = null;
      _trainingGraphicsPickerPreselected = <int>[];
    });
  }

  Future<void> _acceptTrainingGraphicsFromWorkspacePicker(
    List<int> selectedIds,
  ) async {
    final block = _trainingGraphicsPickerBlock;
    final sourcePlan = _trainingGraphicsPickerPlan;
    final exerciseIndex = _trainingGraphicsPickerExerciseIndex;

    if (block == null || sourcePlan == null || exerciseIndex == null) {
      _closeTrainingGraphicsPicker();
      return;
    }

    final ids = selectedIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: true);

    if (ids.isEmpty) {
      _closeTrainingGraphicsPicker();
      return;
    }

    setState(() {
      _trainingPlanSchemeLoading = true;
      _trainingPlanSchemeLoadingExercise = exerciseIndex;
    });

    try {
      final meta = await _loadTrainingGraphicsPreviewMeta(ids);
      if (!mounted) return;

      final next = _cloneTrainingPlan(sourcePlan);
      final exercises = _trainingPlanExercises(next);
      if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;

      exercises[exerciseIndex]['schemes'] = <dynamic>[
        for (final id in ids)
          <String, dynamic>{
            'id': id,
            'title': '${meta[id]?['title'] ?? 'Схема $id'}',
            'preview_url': _trainingGraphicAbsoluteUrl(
              '${meta[id]?['preview_url'] ?? meta[id]?['preview'] ?? ''}',
            ),
          },
      ];

      next['exercises'] = exercises;
      _replaceTrainingPlanBlock(block, next);
      _closeTrainingGraphicsPicker();
    } finally {
      if (mounted) {
        setState(() {
          _trainingPlanSchemeLoading = false;
          _trainingPlanSchemeLoadingExercise = null;
        });
      }
    }
  }


  Widget _buildVisualImage(
    _WorkspaceDocBlock block, {
    required bool compact,
  }) {
    final image = block.image!;
    final selected = _selectedImageStart == block.start;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final desiredWidth = maxWidth * image.widthPercent / 100;
        final alignment = image.alignment == 'left'
            ? Alignment.centerLeft
            : image.alignment == 'right'
                ? Alignment.centerRight
                : Alignment.center;
        final imageWidget = GestureDetector(
          onTap: () => setState(() {
            _finishVisualBlockEditing(rebuild: false);
            _selectedImageStart = selected ? null : block.start;
          }),
          child: Container(
            width: desiredWidth,
            constraints: BoxConstraints(
              minHeight: compact ? 100 : 120,
              maxHeight: compact ? 380 : 520,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _green : _line,
                width: selected ? 1.4 : .8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    image.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined,
                                size: 28, color: _muted),
                            const SizedBox(height: 8),
                            Text(
                              'Не удалось показать изображение',
                              textAlign: TextAlign.center,
                              style: AppTypography.caption(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected && !widget.readOnly)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) => _imageResizeDrag = 0,
                      onHorizontalDragUpdate: (details) {
                        _imageResizeDrag += details.delta.dx;
                      },
                      onHorizontalDragEnd: (_) {
                        final steps = (_imageResizeDrag / 18).round();
                        if (steps != 0) {
                          _resizeVisualImage(block, steps * 5);
                        }
                        _imageResizeDrag = 0;
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(9),
                          ),
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          size: 16,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapDown: (details) =>
              _showBlockContextMenu(block, details.globalPosition),
          child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: alignment, child: imageWidget),
              if (selected && !widget.readOnly) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: alignment,
                  child: SizedBox(
                    width: desiredWidth,
                    child: _InlineImageCaptionEditor(
                      key: ValueKey<String>(
                        'image-caption-${block.start}-${image.caption}',
                      ),
                      initialValue: image.caption,
                      onSave: (value) =>
                          _updateVisualImage(block, caption: value),
                    ),
                  ),
                ),
              ] else if (image.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  image.caption,
                  textAlign: image.alignment == 'left'
                      ? TextAlign.left
                      : image.alignment == 'right'
                          ? TextAlign.right
                          : TextAlign.center,
                  style: AppTypography.caption(color: _muted),
                ),
              ],
              if (selected && !widget.readOnly) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: alignment,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Draggable<int>(
                        data: block.start,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: _green.withOpacity(.35)),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x16101814),
                                  blurRadius: 16,
                                  offset: Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.drag_indicator_rounded,
                                    size: 16, color: _green),
                                const SizedBox(width: 6),
                                Text(
                                  'Переместить фото',
                                  style: AppTypography.captionMedium(
                                    color: _text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: .35,
                          child: _WordObjectButton(
                            icon: Icons.drag_indicator_rounded,
                            tooltip: 'Перетащить между абзацами',
                            onTap: () {},
                          ),
                        ),
                        child: _WordObjectButton(
                          icon: Icons.drag_indicator_rounded,
                          tooltip: 'Перетащить между абзацами',
                          onTap: () {},
                        ),
                      ),
                      _WordObjectButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Уменьшить',
                        onTap: () => _resizeVisualImage(block, -10),
                      ),
                      _WordObjectLabel(text: '${image.widthPercent}%'),
                      _WordObjectButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Увеличить',
                        onTap: () => _resizeVisualImage(block, 10),
                      ),
                      _WordObjectButton(
                        icon: Icons.format_align_left_rounded,
                        tooltip: 'По левому краю',
                        active: image.alignment == 'left',
                        onTap: () => _updateVisualImage(block, alignment: 'left'),
                      ),
                      _WordObjectButton(
                        icon: Icons.format_align_center_rounded,
                        tooltip: 'По центру',
                        active: image.alignment == 'center',
                        onTap: () => _updateVisualImage(block, alignment: 'center'),
                      ),
                      _WordObjectButton(
                        icon: Icons.format_align_right_rounded,
                        tooltip: 'По правому краю',
                        active: image.alignment == 'right',
                        onTap: () => _updateVisualImage(block, alignment: 'right'),
                      ),
                      _WordObjectButton(
                        icon: Icons.content_copy_rounded,
                        tooltip: 'Копировать изображение',
                        onTap: () => _copyVisualBlock(block),
                      ),
                      _WordObjectButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Удалить изображение',
                        danger: true,
                        onTap: () => _deleteVisualBlock(block),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildVisualTable(
    _WorkspaceDocBlock block, {
    required bool compact,
  }) {
    final dataRows = _visualTableRows(block);
    final selected = _selectedTableStart == block.start;
    var columns = 0;
    for (final row in dataRows) {
      if (row.length > columns) columns = row.length;
    }
    if (columns == 0) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          _showBlockContextMenu(block, details.globalPosition),
      onTap: widget.readOnly
          ? null
          : () => setState(() {
                _finishVisualBlockEditing(rebuild: false);
                _selectedImageStart = null;
                _selectedTableStart = selected ? null : block.start;
              }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? _green : _line,
                  width: selected ? 1.3 : .8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                border: TableBorder.all(color: _line, width: .8),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (var r = 0; r < dataRows.length; r++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: r == 0
                            ? const Color(0xFFF5F8F6)
                            : Colors.white,
                      ),
                      children: [
                        for (var c = 0; c < columns; c++)
                          _InlineTableCellEditor(
                            key: ValueKey<String>(
                              'table-${block.start}-$r-$c-${c < dataRows[r].length ? dataRows[r][c] : ''}',
                            ),
                            initialValue:
                                c < dataRows[r].length ? dataRows[r][c] : '',
                            readOnly: widget.readOnly,
                            header: r == 0,
                            compact: compact,
                            onSave: (value) =>
                                _updateVisualTableCell(block, r, c, value),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (selected && !widget.readOnly) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _WordObjectButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Добавить строку',
                    onTap: () => _addVisualTableRow(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Удалить последнюю строку',
                    onTap: () => _removeVisualTableRow(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.view_column_outlined,
                    tooltip: 'Добавить столбец',
                    onTap: () => _addVisualTableColumn(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.vertical_split_outlined,
                    tooltip: 'Удалить последний столбец',
                    onTap: () => _removeVisualTableColumn(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.content_copy_rounded,
                    tooltip: 'Копировать таблицу',
                    onTap: () => _copyVisualBlock(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Исходный текст таблицы',
                    onTap: () => _editRawBlock(block),
                  ),
                  _WordObjectButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Удалить таблицу',
                    danger: true,
                    onTap: () => _deleteVisualBlock(block),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDocumentContextMenu(Offset globalPosition) async {
    if (widget.readOnly) return;
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(globalPosition),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'paste', child: Text('Вставить')),
        PopupMenuItem(value: 'image', child: Text('Вставить изображение')),
        PopupMenuItem(value: 'table', child: Text('Вставить таблицу')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'text_mode', child: Text('Редактировать как текст')),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'paste':
        await _pasteClipboard();
        break;
      case 'image':
        await _insertImage();
        break;
      case 'table':
        _insertTable();
        break;
      case 'text_mode':
        _setVisualMode(false);
        break;
    }
  }



  static const String _trainingPlanTokenPrefix = WorkspaceTrainingPlanCodec.tokenPrefix;
  static const String _trainingPlanTokenSuffix = WorkspaceTrainingPlanCodec.tokenSuffix;

  Map<String, dynamic> _newTrainingPlanExercise(int index) => <String, dynamic>{
        'index': index,
        'title': '',
        'duration_min': '',
        'intensity': '',
        'repetitions': '',
        'work_time': '',
        'pause_time': '',
        'organization': '',
        'coach_focus': '',
        'schemes': <dynamic>[],
      };

  Map<String, dynamic> _newTrainingPlanData() => <String, dynamic>{
        'version': 2,
        'cycle': '',
        'date': '',
        'club': widget.aiClubName.trim(),
        'trainers': '',
        'team': widget.aiTeamName.trim(),
        'duration_min': '',
        'location': '',
        'players_count': '',
        'theme': '',
        'goal_tech': '',
        'goal_tact': '',
        'goal_fit': '',
        'goal_ment': '',
        'equipment': '',
        'signed_role': '',
        'signed_by': '',
        // Logo shown in the top-left cell of the plan.
        // By default it is loaded from the selected team profile.
        'team_logo_url': '',
        'team_logo_data': '',
        'team_logo_hidden': false,
        'exercises': <dynamic>[_newTrainingPlanExercise(1)],
      };



  Future<String> _loadCurrentTrainingPlanAuthorName() async {
    var userId = widget.aiUserId ?? 0;
    if (userId <= 0) {
      try {
        userId = await PrefUtils.getUserId() ?? 0;
      } catch (_) {}
    }
    if (userId <= 0) return '';

    try {
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/get_user.php'),
        body: <String, String>{'id': '$userId'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return '';

      final raw = decoded['user'] ?? decoded['data'] ?? decoded['profile'];
      if (raw is! Map) return '';

      final user = Map<String, dynamic>.from(raw);
      final last = '${user['last_name'] ?? user['lastname'] ?? ''}'.trim();
      final first = '${user['first_name'] ?? user['firstname'] ?? ''}'.trim();
      final middle =
          '${user['middle_name'] ?? user['patronymic'] ?? user['middleName'] ?? ''}'
              .trim();
      final joined =
          <String>[last, first, middle].where((e) => e.isNotEmpty).join(' ').trim();
      if (joined.isNotEmpty) return joined;

      final full =
          '${user['full_name'] ?? user['fullName'] ?? user['name'] ?? ''}'.trim();
      return full == 'null' ? '' : full;
    } catch (_) {
      return '';
    }
  }

  String _normalizeTrainingPlanLogoUrl(dynamic raw) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty || value == 'null') return '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('www.sportotekaapp.ru/')) return 'https://$value';
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    return 'https://sportotekaapp.ru/$value';
  }

  Future<String> _loadDefaultTrainingPlanTeamLogo() async {
    final teamId = widget.aiTeamId ?? 0;
    if (teamId <= 0) return '';

    Future<String> fromDecoded(dynamic decoded) async {
      if (decoded is! Map) return '';
      final rawTeam = decoded['team'] ?? decoded['data'];
      final team = rawTeam is Map
          ? Map<String, dynamic>.from(rawTeam)
          : Map<String, dynamic>.from(decoded);
      for (final key in const [
        'logo',
        'logo_url',
        'team_logo',
        'team_logo_url',
        'photo',
        'image',
      ]) {
        final url = _normalizeTrainingPlanLogoUrl(team[key]);
        if (url.isNotEmpty) return url;
      }
      return '';
    }

    try {
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/get_team_profile.php'),
        body: <String, String>{'team_id': '$teamId'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final value = await fromDecoded(decoded);
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}

    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/team_profile_extended.php',
      ).replace(
        queryParameters: <String, String>{
          'team_id': '$teamId',
          if ((widget.aiClubId ?? 0) > 0) 'club_id': '${widget.aiClubId}',
        },
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final value = await fromDecoded(decoded);
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}

    return '';
  }

  Uint8List? _decodeTrainingPlanLogoData(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      final data = value.contains(',') ? value.substring(value.indexOf(',') + 1) : value;
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _replaceTrainingPlanLogo(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
  ) async {
    if (widget.readOnly) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    Uint8List? bytes = picked.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        picked.path != null &&
        picked.path!.trim().isNotEmpty) {
      try {
        bytes = await File(picked.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty || !mounted) return;

    final next = _cloneTrainingPlan(current);
    final ext = (picked.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png';
    next['team_logo_data'] = 'data:$mime;base64,${base64Encode(bytes)}';
    next['team_logo_hidden'] = false;
    _replaceTrainingPlanBlock(block, next);
  }

  void _removeTrainingPlanLogo(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
  ) {
    if (widget.readOnly) return;
    final next = _cloneTrainingPlan(current);
    next['team_logo_hidden'] = true;
    _replaceTrainingPlanBlock(block, next);
  }

  Future<void> _restoreDefaultTrainingPlanLogo(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
  ) async {
    if (widget.readOnly) return;
    final logo = await _loadDefaultTrainingPlanTeamLogo();
    if (!mounted) return;
    final next = _cloneTrainingPlan(current);
    next['team_logo_data'] = '';
    next['team_logo_url'] = logo;
    next['team_logo_hidden'] = false;
    _replaceTrainingPlanBlock(block, next);
  }

  Widget _buildTrainingPlanLogo(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan, {
    required bool compact,
  }) {
    final hidden = plan['team_logo_hidden'] == true;
    final data = '${plan['team_logo_data'] ?? ''}'.trim();
    final url = _normalizeTrainingPlanLogoUrl(plan['team_logo_url']);
    final memory = hidden ? null : _decodeTrainingPlanLogoData(data);

    Widget image;
    if (hidden) {
      image = Center(
        child: Text(
          'Логотип\nудалён',
          textAlign: TextAlign.center,
          style: AppTypography.caption(color: _muted).copyWith(fontSize: 9),
        ),
      );
    } else if (memory != null && memory.isNotEmpty) {
      image = Padding(
        padding: const EdgeInsets.all(7),
        child: Image.memory(memory, fit: BoxFit.contain),
      );
    } else if (url.isNotEmpty) {
      image = Padding(
        padding: const EdgeInsets.all(7),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: SportotekaWorkspaceIcon(
              kind: SportotekaWorkspaceIconKind.plans,
              size: 32,
              color: _green,
            ),
          ),
        ),
      );
    } else {
      image = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SportotekaWorkspaceIcon(
            kind: SportotekaWorkspaceIconKind.plans,
            size: 32,
            color: _green,
          ),
          const SizedBox(height: 4),
          Text(
            'SPORTOTEKA',
            textAlign: TextAlign.center,
            style: AppTypography.captionMedium(color: _green).copyWith(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: image),
        if (!widget.readOnly)
          Positioned(
            right: 3,
            top: 3,
            child: PopupMenuButton<String>(
              tooltip: 'Логотип плана',
              padding: EdgeInsets.zero,
              iconSize: 17,
              color: Colors.white,
              surfaceTintColor: Colors.white,
              onSelected: (value) {
                if (value == 'replace') {
                  _replaceTrainingPlanLogo(block, plan);
                } else if (value == 'remove') {
                  _removeTrainingPlanLogo(block, plan);
                } else if (value == 'team') {
                  _restoreDefaultTrainingPlanLogo(block, plan);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'replace',
                  child: Text('Заменить изображение'),
                ),
                PopupMenuItem(
                  value: 'team',
                  child: Text('Вернуть логотип команды'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Удалить логотип'),
                ),
              ],
              icon: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.94),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  size: 15,
                  color: _muted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _encodeTrainingPlanToken(Map<String, dynamic> data) =>
      WorkspaceTrainingPlanCodec.encode(data);

  Map<String, dynamic>? _decodeTrainingPlanToken(String raw) =>
      WorkspaceTrainingPlanCodec.decode(raw);

  Map<String, dynamic> _cloneTrainingPlan(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

  List<Map<String, dynamic>> _trainingPlanExercises(Map<String, dynamic> data) {
    final raw = data['exercises'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
  }

  MapEntry<_WorkspaceDocBlock, Map<String, dynamic>>? _lastTrainingPlanBlock() {
    final blocks = _parseDocumentBlocks();
    for (final block in blocks.reversed) {
      if (block.kind != _WorkspaceDocBlockKind.text) continue;
      final plan = _decodeTrainingPlanToken(block.raw);
      if (plan != null) return MapEntry<_WorkspaceDocBlock, Map<String, dynamic>>(block, plan);
    }
    return null;
  }

  void _replaceTrainingPlanBlock(
    _WorkspaceDocBlock block,
    Map<String, dynamic> plan,
  ) {
    _replaceCanonicalRange(
      block.start,
      block.end,
      _encodeTrainingPlanToken(plan),
    );
  }

  void _updateTrainingPlanField(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
    String key,
    String value,
  ) {
    final next = _cloneTrainingPlan(current);
    next[key] = value;
    _replaceTrainingPlanBlock(block, next);
  }

  void _updateTrainingPlanExerciseField(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
    int exerciseIndex,
    String key,
    String value,
  ) {
    final next = _cloneTrainingPlan(current);
    final exercises = _trainingPlanExercises(next);
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;
    exercises[exerciseIndex][key] = value;
    next['exercises'] = exercises;
    _replaceTrainingPlanBlock(block, next);
  }

  void _appendTrainingPlanExercise(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
  ) {
    final next = _cloneTrainingPlan(current);
    final exercises = _trainingPlanExercises(next);
    exercises.add(_newTrainingPlanExercise(exercises.length + 1));
    for (var i = 0; i < exercises.length; i++) {
      exercises[i]['index'] = i + 1;
    }
    next['exercises'] = exercises;
    _replaceTrainingPlanBlock(block, next);
  }

  void _removeTrainingPlanExercise(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
    int exerciseIndex,
  ) {
    final exercises = _trainingPlanExercises(current);
    if (exercises.length <= 1 || exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return;
    }
    final next = _cloneTrainingPlan(current);
    final nextExercises = _trainingPlanExercises(next)..removeAt(exerciseIndex);
    for (var i = 0; i < nextExercises.length; i++) {
      nextExercises[i]['index'] = i + 1;
    }
    next['exercises'] = nextExercises;
    _replaceTrainingPlanBlock(block, next);
  }

  void _duplicateTrainingPlanExercise(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
    int exerciseIndex,
  ) {
    final next = _cloneTrainingPlan(current);
    final exercises = _trainingPlanExercises(next);
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return;
    exercises.insert(
      exerciseIndex + 1,
      Map<String, dynamic>.from(jsonDecode(jsonEncode(exercises[exerciseIndex])) as Map),
    );
    for (var i = 0; i < exercises.length; i++) {
      exercises[i]['index'] = i + 1;
    }
    next['exercises'] = exercises;
    _replaceTrainingPlanBlock(block, next);
  }

  void _moveTrainingPlanExercise(
    _WorkspaceDocBlock block,
    Map<String, dynamic> current,
    int exerciseIndex,
    int delta,
  ) {
    final next = _cloneTrainingPlan(current);
    final exercises = _trainingPlanExercises(next);
    final target = exerciseIndex + delta;
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length || target < 0 || target >= exercises.length) {
      return;
    }
    final moved = exercises.removeAt(exerciseIndex);
    exercises.insert(target, moved);
    for (var i = 0; i < exercises.length; i++) {
      exercises[i]['index'] = i + 1;
    }
    next['exercises'] = exercises;
    _replaceTrainingPlanBlock(block, next);
  }

  String _trainingPlanExerciseTemplate(int index) {
    return '''
## $index. Упражнение

| Название упражнения | Продолжительность |
| --- | --- |
|  |  мин. |

| Схема / поле | Интенсивность | К-во повторений | Время работы | Пауза |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |

| Организация |
| --- |
|  |

| Тренерский акцент |
| --- |
|  |

''';
  }

  String _trainingPlanTemplateBody() {
    return '''
# План-конспект тренировки

| Недельный цикл | Дата |
| --- | --- |
|  |  |

| Клуб | Тренеры | Команда | Продолжительность |
| --- | --- | --- | --- |
|  |  |  |  мин. |

| Место проведения | К-во игроков |
| --- | --- |
|  |  |

| Тема |  |
| --- | --- |
|  |  |

## Цели

| Техника | Тактика | Фитнес | Ментальность |
| --- | --- | --- | --- |
|  |  |  |  |

| Инвентарь |  |
| --- | --- |
|  |  |

## Упражнения

${_trainingPlanExerciseTemplate(1)}
## Подпись

| План-конспект составил | ФИО |
| --- | --- |
| Должность |  |
''';
  }

  void _insertTrainingPlanTemplate({Map<String, dynamic>? seed}) async {
    if (widget.readOnly) return;

    _finishVisualBlockEditing(rebuild: false);
    final current = _bodyController.text.trimRight();
    final plan = _newTrainingPlanData();
    final incoming = seed ?? const <String, dynamic>{};
    for (final entry in incoming.entries) {
      if (entry.value != null && plan.containsKey(entry.key)) {
        plan[entry.key] = entry.value;
      }
    }

    final loaded = await Future.wait<String>(<Future<String>>[
      _loadDefaultTrainingPlanTeamLogo(),
      _loadCurrentTrainingPlanAuthorName(),
    ]);
    if (!mounted) return;

    final teamLogo = loaded[0].trim();
    final authorName = loaded[1].trim();

    if (teamLogo.isNotEmpty) {
      plan['team_logo_url'] = teamLogo;
      plan['team_logo_hidden'] = false;
    }

    // The coach logged into Sportoteka is visible to the system already,
    // so do not force him to type his own FIO again.
    // Both fields remain editable in the template.
    if (authorName.isNotEmpty) {
      plan['trainers'] = authorName;
      plan['signed_by'] = authorName;
      if ('${plan['signed_role'] ?? ''}'.trim().isEmpty) {
        plan['signed_role'] = 'Тренер';
      }
    }

    final token = _encodeTrainingPlanToken(plan);
    final next = current.isEmpty ? token : '$current\n\n$token';

    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );

    if (_visualMode && mounted) setState(() {});
    _focusEditing();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Шаблон плана вставлен. Создано только упражнение 1.',
        ),
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  int _nextTrainingExerciseNumber() {
    final matches = RegExp(
      r'(?:^|\n)#{1,3}\s*(?:(\d+)\.\s*Упражнение|Упражнение\s+(\d+))',
      caseSensitive: false,
    ).allMatches(_bodyController.text);

    var maxIndex = 0;
    for (final match in matches) {
      final value = int.tryParse(
            (match.group(1) ?? match.group(2) ?? '').trim(),
          ) ??
          0;
      if (value > maxIndex) maxIndex = value;
    }
    return maxIndex + 1;
  }

  void _insertNextTrainingExercise() {
    if (widget.readOnly) return;

    final structured = _lastTrainingPlanBlock();
    if (structured != null) {
      _appendTrainingPlanExercise(structured.key, structured.value);
      final count = _trainingPlanExercises(structured.value).length + 1;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Добавлено упражнение $count'),
            duration: const Duration(milliseconds: 1300),
          ),
        );
      }
      return;
    }

    final index = _nextTrainingExerciseNumber();
    final block = _trainingPlanExerciseTemplate(index).trim();

    _finishVisualBlockEditing(rebuild: false);
    final current = _bodyController.text.trimRight();

    // Keep all exercises inside the «Упражнения» section. If the standard
    // template contains the signature block, insert the new exercise before it.
    final signatureMarker = RegExp(
      r'\n##\s+Подпись\b',
      caseSensitive: false,
    ).firstMatch(current);

    final String next;
    final int caretOffset;
    if (current.isEmpty) {
      next = block;
      caretOffset = next.length;
    } else if (signatureMarker != null) {
      final before = current.substring(0, signatureMarker.start).trimRight();
      final after = current.substring(signatureMarker.start).trimLeft();
      final inserted = '$before\n\n$block\n\n';
      next = '$inserted$after';
      caretOffset = inserted.length;
    } else {
      next = '$current\n\n$block';
      caretOffset = next.length;
    }

    _bodyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caretOffset),
    );

    if (_visualMode && mounted) setState(() {});
    _focusEditing();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлено упражнение $index'),
        duration: const Duration(milliseconds: 1300),
      ),
    );
  }

  String _trainingGraphicAbsoluteUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return 'https://sportotekaapp.ru$value';
    }
    return 'https://sportotekaapp.ru/$value';
  }

  Future<Map<int, Map<String, dynamic>>> _loadTrainingGraphicsPreviewMeta(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return <int, Map<String, dynamic>>{};

    try {
      final response = await http.post(
        Uri.parse(
          'https://sportotekaapp.ru/api/get_training_graphics_previews.php',
        ),
        headers: const <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(<String, dynamic>{'ids': ids}),
      );

      if (response.statusCode != 200) {
        return <int, Map<String, dynamic>>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['success'] != true) {
        return <int, Map<String, dynamic>>{};
      }

      final raw = decoded['items'];
      if (raw is! List) return <int, Map<String, dynamic>>{};

      final result = <int, Map<String, dynamic>>{};
      for (final item in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final id = int.tryParse('${map['id'] ?? 0}') ?? 0;
        if (id > 0) result[id] = map;
      }
      return result;
    } catch (_) {
      return <int, Map<String, dynamic>>{};
    }
  }

  Future<void> _insertTrainingGraphicFromEditor() async {
    if (widget.readOnly) return;

    final structured = _lastTrainingPlanBlock();
    if (structured != null) {
      final exercises = _trainingPlanExercises(structured.value);
      final target = exercises.isEmpty ? 0 : exercises.length - 1;
      if (exercises.isEmpty) {
        _appendTrainingPlanExercise(structured.key, structured.value);
        return;
      }
      await _pickTrainingGraphicForPlanExercise(
        structured.key,
        structured.value,
        target,
      );
      return;
    }


    final clubId = widget.aiClubId ?? 0;
    final teamId = widget.aiTeamId ?? 0;

    if (clubId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для выбора схемы нужен контекст клуба. Откройте документ из Sportoteka OS ещё раз.',
          ),
        ),
      );
      return;
    }

    _syncVisualBlockIfNeeded();

    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => PlanFoldersScreen(
          clubId: clubId,
          clubName: widget.aiClubName.trim().isEmpty
              ? 'Клуб'
              : widget.aiClubName.trim(),
          teamId: teamId > 0 ? teamId : null,
          selectGraphicsMode: true,
          preselectedGraphicIds: const <int>[],
          browsePlansMode: false,
          initialParentId: null,
          initialParentTitle: 'Все материалы',
        ),
      ),
    );

    if (!mounted || result == null) return;

    final ids = <int>[];
    if (result is List) {
      for (final raw in result) {
        final id = int.tryParse('$raw') ?? 0;
        if (id > 0 && !ids.contains(id)) ids.add(id);
      }
    } else if (result is Map) {
      final raw = result['selected'] ?? result['ids'] ?? result['schemes'];
      if (raw is List) {
        for (final value in raw) {
          final id = int.tryParse('$value') ?? 0;
          if (id > 0 && !ids.contains(id)) ids.add(id);
        }
      }
    }
    if (ids.isEmpty) return;

    final meta = await _loadTrainingGraphicsPreviewMeta(ids);
    if (!mounted) return;

    final chunks = <String>[];
    for (final id in ids) {
      final item = meta[id] ?? const <String, dynamic>{};
      final preview = _trainingGraphicAbsoluteUrl(
        '${item['preview_url'] ?? item['preview'] ?? ''}',
      );
      final rawTitle = '${item['title'] ?? ''}'.trim();
      final title = rawTitle.isEmpty ? 'Схема $id' : rawTitle;

      if (preview.isNotEmpty) {
        chunks.add('![$title]($preview){width=100%;align=center}');
      } else {
        chunks.add('**$title** · Sportoteka Graphics #$id');
      }
    }

    _replaceBodySelection('\n${chunks.join('\n\n')}\n');
    _finishVisualBlockEditing();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ids.length == 1
              ? 'Схема вставлена в план'
              : 'В план вставлено схем: ${ids.length}',
        ),
        duration: const Duration(milliseconds: 1400),
      ),
    );
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

  String get _displayDocumentText => _exportPlainText(_bodyController.text);

  int get _wordCount {
    final value = _displayDocumentText.trim();
    if (value.isEmpty) return 0;
    return value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
  }

  int get _displayCharCount => _displayDocumentText.length;

  Future<void> _copyDocument() async {
    final title = _titleController.text.trim();
    final body = _displayDocumentText;
    final value = <String>[title, body]
        .where((part) => part.trim().isNotEmpty)
        .join('\n\n');
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
        _EditorTemplate('Наблюдение',
            'Наблюдение за игроком\n\nСильные стороны\n• \n\nЗона развития\n• \n\nСледующий шаг\n☐ '),
        _EditorTemplate('Личная цель',
            'Цель игрока\n\nЧто развиваем\n\nКритерий результата\n\nСрок\n\n☐ Контрольная точка'),
        _EditorTemplate('Обратная связь',
            'Обратная связь\n\nЧто получилось\n\nЧто улучшить\n\nДоговорённость с игроком'),
        _EditorTemplate('Итоги периода',
            'Итоги периода\n\nПрогресс\n\nНагрузка и готовность\n\nПриоритет следующего периода'),
      ];
    }
    if (context.contains('тренер')) {
      return const <_EditorTemplate>[
        _EditorTemplate('Рабочая запись',
            'Рабочая запись тренера\n\nЗадача\n\nРешение\n\n☐ Следующее действие'),
        _EditorTemplate('Методика',
            'Методическая заметка\n\nЦель\n\nОрганизация\n\nКлючевые подсказки\n\nВарианты усложнения'),
        _EditorTemplate('Разбор',
            'Разбор работы\n\nЧто сработало\n\nЧто изменить\n\nРешение на следующую тренировку'),
        _EditorTemplate('Договорённость',
            'Договорённость\n\nУчастники\n\nРешение\n\nСрок\n\n☐ Проверить выполнение'),
      ];
    }
    if (context.contains('команд')) {
      return const <_EditorTemplate>[
        _EditorTemplate('Командная цель',
            'Командная цель\n\nФокус\n\nКритерий результата\n\n☐ Следующий шаг'),
        _EditorTemplate('Разбор матча',
            'Разбор матча\n\nСильные эпизоды\n\nЧто исправить\n\nФокус микроцикла'),
        _EditorTemplate('План недели',
            'План недели\n\nГлавная задача\n\nНагрузка\n\nКонтрольные точки'),
        _EditorTemplate('Собрание',
            'Итоги собрания\n\nРешения\n\nОтветственные\n\n☐ Следующая встреча'),
      ];
    }
    return const <_EditorTemplate>[
      _EditorTemplate(
          'Быстрая заметка', 'Кратко\n\nГлавная мысль\n\n☐ Следующее действие'),
      _EditorTemplate(
          'Итоги', 'Итоги\n\nЧто сделано\n\nЧто осталось\n\nСледующий шаг'),
      _EditorTemplate('План', 'Цель\n\nШаги\n☐ \n☐ \n☐ \n\nСрок'),
      _EditorTemplate('Встреча',
          'Встреча\n\nУчастники\n\nОбсудили\n\nРешили\n\n☐ Контроль'),
    ];
  }

  bool get _methodDocumentMode => widget.aiExtraPayload['document_ai'] == true;

  String get _sourceDocumentName {
    final value = '${widget.aiExtraPayload['document_filename'] ?? ''}'.trim();
    return value.isEmpty ? widget.initialTitle : value;
  }

  String get _sourceDocumentUrl =>
      '${widget.aiExtraPayload['document_file_url'] ?? ''}'.trim();

  String get _sourceDocumentExtension {
    final value = '${widget.aiExtraPayload['document_extension'] ?? ''}'.trim();
    return value.replaceFirst('.', '').toUpperCase();
  }

  int get _sourceDocumentSize {
    final raw = widget.aiExtraPayload['document_file_size'];
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? 0;
  }

  String _sourceSizeLabel() {
    final bytes = _sourceDocumentSize;
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }

  Future<void> _openOriginalSourceDocument() async {
    final raw = _sourceDocumentUrl;
    if (raw.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка на оригинальный документ недоступна'),
        ),
      );
      return;
    }

    await openWorkspaceAttachmentPreview(
      context,
      title: _sourceDocumentName,
      fileUrl: raw,
      mimeType:
          _sourceDocumentExtension == 'PDF' ? 'application/pdf' : '',
    );
  }

  void _openAiAnalysis() {
    if (!_aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ИИ-контекст для этого документа пока недоступен'),
        ),
      );
      return;
    }
    setState(() => _aiExpanded = true);
  }

  bool get _aiEnabled =>
      (widget.aiClubId ?? 0) > 0 && (widget.aiUserId ?? 0) > 0;

  String get _aiDocumentKey {
    final explicit = (widget.aiDocumentKey ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    final live = _effectiveLiveBlocksKey.trim();
    if (live.isNotEmpty) return live;
    return '${widget.contextLabel}:${widget.contextName}:${widget.initialTitle}';
  }

  String _selectedTextForAi() {
    final selection = _bodyController.selection;
    final body = _bodyController.text;
    if (!selection.isValid || selection.isCollapsed) return '';
    final start = selection.start.clamp(0, body.length).toInt();
    final end = selection.end.clamp(0, body.length).toInt();
    if (end <= start) return '';
    return body.substring(start, end);
  }

  Map<String, dynamic> _aiPayload() {
    return <String, dynamic>{
      ...widget.aiExtraPayload,
      'scope': 'workspace_document',
      'workspace_section': widget.contextLabel,
      'workspace_document': <String, dynamic>{
        'document_key': _aiDocumentKey,
        'title': _titleController.text.trim().isEmpty
            ? widget.initialTitle
            : _titleController.text.trim(),
        'body': _bodyController.text,
        'selected_text': _selectedTextForAi(),
        'context_label': widget.contextLabel,
        'context_name': widget.contextName,
        'document_type': widget.documentType,
      },
    };
  }

  String _aiInitialPrompt() {
    final label = widget.contextLabel.trim();
    final title = _titleController.text.trim().isEmpty
        ? widget.initialTitle
        : _titleController.text.trim();
    final normalized = label.toLowerCase();

    if (normalized.contains('трениров')) {
      return 'Проанализируй текущий документ тренировки «$title». '
          'Сначала разберись в тексте документа, затем, если это уместно, '
          'сопоставь его только с проверенными данными этой тренировки и команды. '
          'Дай коротко: что важно, что требует внимания и что делать тренеру.';
    }
    if (normalized.contains('матч')) {
      return 'Проанализируй текущий документ матча «$title». '
          'Выдели ключевые решения, тактические моменты и следующие действия. '
          'Если нужны данные матча или игроков, используй только проверенные данные SPORTOTEKA.';
    }
    if (normalized.contains('игрок')) {
      return 'Проанализируй текущий документ игрока «$title». '
          'Сопоставляй текст с данными игрока только когда они действительно нужны '
          'и используй только проверенные показатели SPORTOTEKA.';
    }
    if (normalized.contains('тренер')) {
      return 'Проанализируй текущий рабочий документ тренера «$title». '
          'Помоги улучшить формулировки, структуру, план и практические действия.';
    }
    if (normalized.contains('календар')) {
      return 'Проанализируй текущий документ календаря «$title». '
          'Выдели задачи, сроки, риски и следующие действия.';
    }
    if (widget.documentType.toLowerCase().contains('метод')) {
      return 'Разбери методический документ «$title». '
          'Выдели ключевые принципы, упражнения, ограничения и практическое применение. '
          'Не придумывай того, чего нет в документе.';
    }
    return 'Проанализируй текущий документ «$title» в разделе «$label». '
        'Сделай краткий разбор, выдели главное и предложи следующие действия. '
        'Используй текст документа и только проверенные данные SPORTOTEKA.';
  }

  String get _aiContextTitle => 'ИИ анализ · ${widget.contextLabel}';

  String get _aiContextSubtitle {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) return title;
    if (widget.contextName.trim().isNotEmpty) return widget.contextName.trim();
    return widget.documentType;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) {
            _save();
            return null;
          }),
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
            _undo();
            return null;
          }),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
            _redo();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final sidePickerOpen =
                  _sidePickerType != null || _trainingGraphicsPickerOpen;
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
                      child: _trainingGraphicsPickerOpen
                          ? _WorkspaceTrainingGraphicsPickerPane(
                              clubId: widget.aiClubId ?? 0,
                              teamId: widget.aiTeamId ?? 0,
                              clubName: widget.aiClubName,
                              teamName: widget.aiTeamName,
                              preselectedIds:
                                  _trainingGraphicsPickerPreselected,
                              onClose: _closeTrainingGraphicsPicker,
                              onSelected:
                                  _acceptTrainingGraphicsFromWorkspacePicker,
                            )
                          : WorkspaceLiveBlockPickerPane(
                              type: _sidePickerType!,
                              onClose: () =>
                                  setState(() => _sidePickerType = null),
                              onSelected: (block) async =>
                                  _acceptLiveBlock(block),
                            ),
                    ),
                ],
              );

              final editor = Material(
                color: _surface,
                child: Column(
                  children: [
                    if (!widget.compactWorkspaceChrome)
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
                                      onTap: () {
                                        if (_trainingGraphicsPickerOpen) {
                                          _closeTrainingGraphicsPicker();
                                        } else {
                                          setState(() => _sidePickerType = null);
                                        }
                                      },
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
                                    child: _trainingGraphicsPickerOpen
                                        ? _WorkspaceTrainingGraphicsPickerPane(
                                            clubId: widget.aiClubId ?? 0,
                                            teamId: widget.aiTeamId ?? 0,
                                            clubName: widget.aiClubName,
                                            teamName: widget.aiTeamName,
                                            preselectedIds:
                                                _trainingGraphicsPickerPreselected,
                                            onClose:
                                                _closeTrainingGraphicsPicker,
                                            onSelected:
                                                _acceptTrainingGraphicsFromWorkspacePicker,
                                          )
                                        : WorkspaceLiveBlockPickerPane(
                                            type: _sidePickerType!,
                                            onClose: () => setState(
                                                () => _sidePickerType = null),
                                            onSelected: (block) async =>
                                                _acceptLiveBlock(block),
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

              if (!_aiEnabled) return editor;

              return CmrContextAiLayer(
                child: editor,
                expanded: _aiExpanded,
                onToggle: () => setState(() => _aiExpanded = !_aiExpanded),
                clubId: widget.aiClubId!,
                userId: widget.aiUserId!,
                teamId: widget.aiTeamId,
                clubName: widget.aiClubName,
                teamName: widget.aiTeamName,
                contextTitle: _aiContextTitle,
                contextSubtitle: _aiContextSubtitle,
                initialPrompt: _aiInitialPrompt(),
                initialPayload: _aiPayload(),
                panelKey: ValueKey<String>('workspace-ai:$_aiDocumentKey'),
                bottomInset: 12,
                showCollapsedLauncher: false,
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
                Text(
                  _methodDocumentMode
                      ? (_titleController.text.trim().isEmpty
                          ? widget.initialTitle
                          : _titleController.text.trim())
                      : 'SPORTOTEKA OS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _methodDocumentMode
                      ? AppTypography.sectionTitle(color: _text)
                          .copyWith(fontSize: compact ? 14.5 : 15.5)
                      : AppTypography.menuGroup(color: _green),
                ),
                if (!compact)
                  Text(
                    _methodDocumentMode
                        ? (widget.contextName.trim().isEmpty
                            ? 'Методические материалы · SPORTOTEKA OS'
                            : 'Методические материалы · ${widget.contextName}')
                        : (widget.contextName.trim().isEmpty
                            ? widget.contextLabel
                            : '${widget.contextLabel} · ${widget.contextName}'),
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
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                    Text('Сохранить',
                        style: AppTypography.actionStrong(color: Colors.white)),
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
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.menuTitle(color: _text)),
                    ),
                  ],
                ),
                if (widget.contextName.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.contextName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.itemTitle(color: _text)),
                ],
                const SizedBox(height: 9),
                Text(widget.documentType,
                    style: AppTypography.caption(color: _muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!widget.readOnly) ...[
            Text('УМНЫЙ ДОКУМЕНТ',
                style: AppTypography.menuGroup(color: _muted)),
            const SizedBox(height: 9),
            _EditorTemplateButton(
                title: 'Собрать отчёт из блоков', onTap: _buildSmartReport),
            const SizedBox(height: 22),
          ],
          Text('БЫСТРЫЙ СТАРТ', style: AppTypography.menuGroup(color: _muted)),
          const SizedBox(height: 9),
          for (final template in _templates)
            _EditorTemplateButton(
                title: template.title, onTap: () => _insertTemplate(template)),
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
          wordCompact: widget.compactWorkspaceChrome,
          readOnly: widget.readOnly,
          visualMode: _visualMode,
          saving: _saving,
          dirty: _dirty,
          failed: _saveError,
          canSave: !widget.readOnly && widget.onSave != null,
          onSave: _save,
          onExportDoc: () => _exportDoc(),
          onExportPdf: () => _exportPdf(),
          onShareDoc: () => _exportDoc(share: true),
          onSharePdf: () => _exportPdf(share: true),
          canUndo: _canUndo,
          canRedo: _canRedo,
          onUndo: _undo,
          onRedo: _redo,
          onVisualModeChanged: _setVisualMode,
          onFontSize: _applyFontSize,
          onTextColor: _applyTextColor,
          onHighlight: _applyHighlight,
          onAlignment: _applyAlignment,
          onBold: () => _wrapSelection('**', '**'),
          onItalic: () => _wrapSelection('_', '_'),
          onUnderline: () => _wrapSelection('__', '__'),
          onStrike: () => _wrapSelection('~~', '~~'),
          onHeading: () => _prefixSelection('## '),
          onBullet: () => _prefixSelection('• '),
          onNumbered: () => _prefixSelection('1. '),
          onChecklist: () => _prefixSelection('☐ '),
          onQuote: () => _prefixSelection('> '),
          onCopy: _copySelection,
          onCut: _cutSelection,
          onPaste: _pasteClipboard,
          onSelectAll: _selectAllBody,
          onDuplicate: _duplicateSelection,
          onLink: _insertLink,
          onImage: _insertImage,
          onImageSmaller: () => _resizeNearestImage(-10),
          onImageLarger: () => _resizeNearestImage(10),
          onTable: _insertTable,
          onRule: _insertHorizontalRule,
          onDateTime: _insertDateTime,
          onInsert: _insertLiveBlock,
          onInsertTrainingTemplate: _insertTrainingPlanTemplate,
          onAddTrainingExercise: _insertNextTrainingExercise,
          onInsertTrainingGraphic: _insertTrainingGraphicFromEditor,
          onAiAnalysis:
              (_aiEnabled || _methodDocumentMode) ? _openAiAnalysis : null,
          aiActive: _aiExpanded,
        ),
        if (compact && widget.showTemplates && !widget.readOnly)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: _templates.length + 3,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return ActionChip(
                    onPressed: _insertTrainingPlanTemplate,
                    backgroundColor: const Color(0xFFEAF5EF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    avatar: const Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: _green,
                    ),
                    label: Text('Шаблон плана',
                        style: AppTypography.captionMedium(color: _green)),
                  );
                }
                if (index == 1) {
                  return ActionChip(
                    onPressed: _buildSmartReport,
                    backgroundColor: const Color(0xFFEAF5EF),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    label: Text('Собрать отчёт',
                        style: AppTypography.captionMedium(color: _green)),
                  );
                }
                if (index == 2) {
                  return ActionChip(
                    onPressed: _insertPlanBlock,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    label: Text('+ План-конспект',
                        style: AppTypography.captionMedium(color: _green)),
                  );
                }
                final template = _templates[index - 3];
                return ActionChip(
                  onPressed: () => _insertTemplate(template),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  label: Text(template.title,
                      style: AppTypography.captionMedium(color: _text)),
                );
              },
            ),
          ),
        if (_visualMode && !compact) const _WordRuler(),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF1F3F2),
            child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 26,
              compact ? 12 : 22,
              compact ? 10 : 26,
              compact ? 28 : 44,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? 900 : 794,
                  minHeight: compact ? 520 : 1120,
                ),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 38,
                    compact ? 20 : 30,
                    compact ? 18 : 38,
                    compact ? 30 : 44,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(compact ? 12 : 14),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x0E142219),
                          blurRadius: 30,
                          spreadRadius: -8,
                          offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _EditorMosaicStrip(),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(widget.documentType.toUpperCase(),
                                  style:
                                      AppTypography.menuGroup(color: _muted))),
                          Text(_todayLabel(),
                              style: AppTypography.caption(color: _muted)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _titleController,
                        readOnly: widget.readOnly || widget.titleReadOnly,
                        maxLines: null,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Название заметки',
                          hintStyle: AppTypography.screenTitle(
                                  color: const Color(0xFFAAB2AD))
                              .copyWith(fontSize: compact ? 20 : 24),
                        ),
                        style: AppTypography.screenTitle(color: _text).copyWith(
                            fontSize: compact ? 20 : 24, height: 1.16),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _EditorMetaChip(text: widget.contextLabel),
                          if (widget.contextName.trim().isNotEmpty)
                            _EditorMetaChip(text: widget.contextName),
                          _EditorMetaChip(text: '$_wordCount слов'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(height: 1, color: _line),
                      const SizedBox(height: 18),
                      if (_liveBlocksLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: LinearProgressIndicator(
                              minHeight: 2,
                              color: _green,
                              backgroundColor: Color(0xFFEAF1ED)),
                        ),
                      if (_liveBlocks.isNotEmpty) ...[
                        Row(
                          children: [
                            Text('СВЯЗАННЫЕ МАТЕРИАЛЫ',
                                style: AppTypography.menuGroup(color: _muted)),
                            const SizedBox(width: 8),
                            const _EditorMosaicStrip(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (int index = 0;
                            index < _liveBlocks.length;
                            index++) ...[
                          WorkspaceLiveBlockCard(
                            key: ValueKey(
                                '${_liveBlocks[index].type.name}:${_liveBlocks[index].entityId}'),
                            block: _liveBlocks[index],
                            readOnly: widget.readOnly,
                            onChanged: (value) =>
                                _replaceLiveBlock(index, value),
                            onRemove: () => _removeLiveBlock(index),
                          ),
                          const SizedBox(height: 9),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: _line),
                        const SizedBox(height: 18),
                      ] else
                        const SizedBox(height: 4),
                      if (_methodDocumentMode) ...[
                        _ImportedSourceDocumentBlock(
                          filename: _sourceDocumentName,
                          extension: _sourceDocumentExtension,
                          sizeLabel: _sourceSizeLabel(),
                          onOpen: _sourceDocumentUrl.isEmpty
                              ? null
                              : _openOriginalSourceDocument,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.text_snippet_outlined,
                              size: 18,
                              color: _green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'РАСПОЗНАННЫЙ ТЕКСТ',
                                style: AppTypography.menuGroup(
                                  color: _muted,
                                ),
                              ),
                            ),
                            if (_showImportedTextBlock)
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _showImportedTextBlock = false,
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                ),
                                label: const Text('Убрать блок'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _muted,
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _showImportedTextBlock = true,
                                ),
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                ),
                                label: const Text('Вернуть текст'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _green,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_showImportedTextBlock)
                          Container(
                            padding: EdgeInsets.all(compact ? 12 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBFCFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: TextField(
                              controller: _bodyController,
                              focusNode: _bodyFocus,
                              readOnly: widget.readOnly,
                              minLines: compact ? 18 : 24,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Распознанный текст документа…',
                                hintStyle: AppTypography.body(
                                  color: const Color(0xFFA2ABA5),
                                ).copyWith(
                                  fontSize: compact ? 14 : 15,
                                  height: 1.62,
                                ),
                              ),
                              style: AppTypography.body(color: _text).copyWith(
                                fontSize: compact ? 14 : 15,
                                height: 1.62,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F8F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: Text(
                              'Распознанный текст скрыт. Оригинальный файл '
                              'сохранён выше и текст можно вернуть в любой момент.',
                              style: AppTypography.caption(color: _muted),
                            ),
                          ),
                      ] else if (_visualMode)
                        _buildVisualDocument(compact: compact)
                      else
                        TextField(
                          controller: _bodyController,
                          focusNode: _bodyFocus,
                          readOnly: widget.readOnly,
                          minLines: compact ? 20 : 26,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration.collapsed(
                            hintText:
                                'Начните писать или выберите шаблон заметки…',
                            hintStyle: AppTypography.body(
                              color: const Color(0xFFA2ABA5),
                            ).copyWith(
                              fontSize: compact ? 14 : 15,
                              height: 1.62,
                            ),
                          ),
                          style: AppTypography.body(color: _text).copyWith(
                            fontSize: compact ? 14 : 15,
                            height: 1.62,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
        Container(
          height: widget.compactWorkspaceChrome ? 24 : 31,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Text('$_wordCount слов · $_displayCharCount знаков',
                  style: AppTypography.caption(color: _muted)),
              const Spacer(),
              if (!compact && !widget.compactWorkspaceChrome)
                Text(
                  widget.autoSave && widget.onSave != null
                      ? 'Автосохранение включено'
                      : 'Сохранение вручную',
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



class _WordRuler extends StatelessWidget {
  const _WordRuler();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: const Color(0xFFF7F8F7),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Expanded(
            child: CustomPaint(
              painter: _WordRulerPainter(),
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _WordRulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFFCFD6D2)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFAAB4AE)
      ..strokeWidth = 1;
    final baseline = Paint()
      ..color = const Color(0xFFE2E6E3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), baseline);
    const step = 18.0;
    var x = 0.0;
    var index = 0;
    while (x <= size.width) {
      final isMajor = index % 5 == 0;
      final height = isMajor ? 9.0 : (index % 2 == 0 ? 6.0 : 4.0);
      canvas.drawLine(
        Offset(x, size.height - 1),
        Offset(x, size.height - 1 - height),
        isMajor ? major : minor,
      );
      x += step;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant _WordRulerPainter oldDelegate) => false;
}

enum _WorkspaceDocBlockKind { text, image, table, rule, spacer }

class _WorkspaceDocLine {
  const _WorkspaceDocLine({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final int start;
  final int end;
}

class _InlineImageCaptionEditor extends StatefulWidget {
  const _InlineImageCaptionEditor({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  final String initialValue;
  final ValueChanged<String> onSave;

  @override
  State<_InlineImageCaptionEditor> createState() =>
      _InlineImageCaptionEditorState();
}

class _InlineImageCaptionEditorState
    extends State<_InlineImageCaptionEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String _lastSaved = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSaved = widget.initialValue;
    _focus = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!_focus.hasFocus) _save();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value == _lastSaved) return;
    _lastSaved = value;
    widget.onSave(value);
  }

  @override
  void dispose() {
    _save();
    _focus
      ..removeListener(_handleFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: 2,
      minLines: 1,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        hintText: 'Подпись к изображению',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F8F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Сохранить подпись',
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF177B57)),
        ),
      ),
      style: AppTypography.caption(color: const Color(0xFF758079)),
    );
  }
}

class _InlineTableCellEditor extends StatefulWidget {
  const _InlineTableCellEditor({
    super.key,
    required this.initialValue,
    required this.readOnly,
    required this.header,
    required this.compact,
    required this.onSave,
  });

  final String initialValue;
  final bool readOnly;
  final bool header;
  final bool compact;
  final ValueChanged<String> onSave;

  @override
  State<_InlineTableCellEditor> createState() => _InlineTableCellEditorState();
}

class _InlineTableCellEditorState extends State<_InlineTableCellEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String _lastSaved = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSaved = widget.initialValue;
    _focus = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!_focus.hasFocus) _save();
  }

  void _save() {
    if (widget.readOnly) return;
    final value = _controller.text.trim();
    if (value == _lastSaved) return;
    _lastSaved = value;
    widget.onSave(value);
  }

  @override
  void dispose() {
    _save();
    _focus
      ..removeListener(_handleFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      readOnly: widget.readOnly,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF177B57), width: .8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 7 : 9,
          vertical: widget.compact ? 7 : 9,
        ),
      ),
      onSubmitted: (_) => _save(),
      style: (widget.header
              ? AppTypography.captionMedium(color: const Color(0xFF101814))
              : AppTypography.caption(color: const Color(0xFF101814)))
          .copyWith(fontSize: widget.compact ? 11.5 : 12.5),
    );
  }
}

class _WorkspaceDocBlock {
  const _WorkspaceDocBlock({
    required this.kind,
    required this.start,
    required this.end,
    required this.raw,
    this.image,
  });

  final _WorkspaceDocBlockKind kind;
  final int start;
  final int end;
  final String raw;
  final _WorkspaceVisualImageData? image;
}

class _WorkspaceVisualImageData {
  const _WorkspaceVisualImageData({
    required this.caption,
    required this.url,
    required this.widthPercent,
    required this.alignment,
  });

  final String caption;
  final String url;
  final int widthPercent;
  final String alignment;

  static _WorkspaceVisualImageData? tryParse(String raw) {
    final match = RegExp(
      r'^!\[([^\]]*)\]\(([^\)]+)\)\{width=(\d+)%(?:;align=(left|center|right))?\}\s*$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    return _WorkspaceVisualImageData(
      caption: match.group(1) ?? '',
      url: match.group(2) ?? '',
      widthPercent: (int.tryParse(match.group(3) ?? '') ?? 100).clamp(20, 100).toInt(),
      alignment: match.group(4) ?? 'center',
    );
  }

  _WorkspaceVisualImageData copyWith({
    String? caption,
    String? url,
    int? widthPercent,
    String? alignment,
  }) {
    return _WorkspaceVisualImageData(
      caption: caption ?? this.caption,
      url: url ?? this.url,
      widthPercent: widthPercent ?? this.widthPercent,
      alignment: alignment ?? this.alignment,
    );
  }

  String toMarkup() =>
      '![$caption]($url){width=${widthPercent.clamp(20, 100)}%;align=$alignment}';
}

class _WorkspaceTextBlockStyle {
  const _WorkspaceTextBlockStyle({
    required this.content,
    required this.headingLevel,
    required this.quote,
    required this.textAlign,
  });

  final String content;
  final int headingLevel;
  final bool quote;
  final TextAlign textAlign;

  static _WorkspaceTextBlockStyle parse(String raw) {
    var value = raw;
    var align = TextAlign.left;
    final alignMatch = RegExp(r'^<align:(left|center|right|justify)>').firstMatch(value);
    if (alignMatch != null) {
      switch (alignMatch.group(1)) {
        case 'center':
          align = TextAlign.center;
          break;
        case 'right':
          align = TextAlign.right;
          break;
        case 'justify':
          align = TextAlign.justify;
          break;
        default:
          align = TextAlign.left;
      }
      value = value.substring(alignMatch.end);
    }

    var heading = 0;
    if (value.startsWith('### ')) {
      heading = 3;
      value = value.substring(4);
    } else if (value.startsWith('## ')) {
      heading = 2;
      value = value.substring(3);
    } else if (value.startsWith('# ')) {
      heading = 1;
      value = value.substring(2);
    }

    var quote = false;
    if (value.startsWith('> ')) {
      quote = true;
      value = value.substring(2);
    }

    return _WorkspaceTextBlockStyle(
      content: value,
      headingLevel: heading,
      quote: quote,
      textAlign: align,
    );
  }

  TextStyle baseStyle({required bool compact, required Color color}) {
    if (headingLevel == 1) {
      return AppTypography.screenTitle(color: color).copyWith(
        fontSize: compact ? 22 : 26,
        height: 1.25,
      );
    }
    if (headingLevel == 2) {
      return AppTypography.sectionTitle(color: color).copyWith(
        fontSize: compact ? 18 : 21,
        height: 1.3,
      );
    }
    if (headingLevel == 3) {
      return AppTypography.subsectionTitle(color: color).copyWith(
        fontSize: compact ? 15.5 : 17,
        height: 1.4,
      );
    }
    return AppTypography.body(color: color).copyWith(
      fontSize: compact ? 14 : 15,
      height: 1.62,
      fontStyle: quote ? FontStyle.italic : FontStyle.normal,
    );
  }
}

Color _workspaceHexColor(String raw, Color fallback) {
  var value = raw.trim().replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

TextSpan _workspaceRichSpan(String raw, TextStyle baseStyle) {
  final children = <InlineSpan>[];
  final token = RegExp(
    r'(\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~|_(.+?)_|<fs:(\d{1,2})>(.+?)</fs>|<c:([0-9A-Fa-f]{6,8})>(.+?)</c>|<bg:([0-9A-Fa-f]{6,8})>(.+?)</bg>|\[([^\]]+)\]\(([^\)]+)\))',
  );
  var cursor = 0;
  for (final match in token.allMatches(raw)) {
    if (match.start > cursor) {
      children.add(TextSpan(text: raw.substring(cursor, match.start), style: baseStyle));
    }
    final whole = match.group(0) ?? '';
    TextStyle style = baseStyle;
    String text = whole;
    if (whole.startsWith('**')) {
      text = match.group(2) ?? '';
      style = style.copyWith(fontWeight: FontWeight.w700);
    } else if (whole.startsWith('__')) {
      text = match.group(3) ?? '';
      style = style.copyWith(decoration: TextDecoration.underline);
    } else if (whole.startsWith('~~')) {
      text = match.group(4) ?? '';
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    } else if (whole.startsWith('_')) {
      text = match.group(5) ?? '';
      style = style.copyWith(fontStyle: FontStyle.italic);
    } else if (whole.startsWith('<fs:')) {
      text = match.group(7) ?? '';
      final size = double.tryParse(match.group(6) ?? '');
      if (size != null) style = style.copyWith(fontSize: size.clamp(8, 48).toDouble());
    } else if (whole.startsWith('<c:')) {
      text = match.group(9) ?? '';
      style = style.copyWith(
        color: _workspaceHexColor(match.group(8) ?? '', baseStyle.color ?? Colors.black),
      );
    } else if (whole.startsWith('<bg:')) {
      text = match.group(11) ?? '';
      style = style.copyWith(
        backgroundColor: _workspaceHexColor(match.group(10) ?? '', Colors.transparent),
      );
    } else if (whole.startsWith('[')) {
      text = match.group(12) ?? '';
      style = style.copyWith(
        color: const Color(0xFF0B8F55),
        decoration: TextDecoration.underline,
      );
    }
    children.add(TextSpan(text: text, style: style));
    cursor = match.end;
  }
  if (cursor < raw.length) {
    children.add(TextSpan(text: raw.substring(cursor), style: baseStyle));
  }
  if (children.isEmpty) return TextSpan(text: raw, style: baseStyle);
  return TextSpan(style: baseStyle, children: children);
}

class _WorkspaceRichTextController extends TextEditingController {
  _WorkspaceRichTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    // Во время редактирования маркеры остаются видимыми, чтобы курсор и
    // выделение всегда совпадали с реальным текстом. Само форматирование
    // показывается сразу цветом/начертанием там, где это возможно.
    return TextSpan(text: text, style: base);
  }
}

class _WordObjectButton extends StatelessWidget {
  const _WordObjectButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFB42318)
        : active
            ? const Color(0xFF0B8F55)
            : const Color(0xFF667085);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? const Color(0xFFEAF5EF) : const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 30,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _WordObjectLabel extends StatelessWidget {
  const _WordObjectLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTypography.captionMedium(color: const Color(0xFF667085)),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.compact,
    required this.wordCompact,
    required this.readOnly,
    required this.visualMode,
    required this.saving,
    required this.dirty,
    required this.failed,
    required this.canSave,
    required this.onSave,
    required this.onExportDoc,
    required this.onExportPdf,
    required this.onShareDoc,
    required this.onSharePdf,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onVisualModeChanged,
    required this.onFontSize,
    required this.onTextColor,
    required this.onHighlight,
    required this.onAlignment,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrike,
    required this.onHeading,
    required this.onBullet,
    required this.onNumbered,
    required this.onChecklist,
    required this.onQuote,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onSelectAll,
    required this.onDuplicate,
    required this.onLink,
    required this.onImage,
    required this.onImageSmaller,
    required this.onImageLarger,
    required this.onTable,
    required this.onRule,
    required this.onDateTime,
    required this.onInsert,
    required this.onInsertTrainingTemplate,
    required this.onAddTrainingExercise,
    required this.onInsertTrainingGraphic,
    this.onAiAnalysis,
    this.aiActive = false,
  });

  final bool compact;
  final bool wordCompact;
  final bool readOnly;
  final bool visualMode;
  final bool saving;
  final bool dirty;
  final bool failed;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onExportDoc;
  final VoidCallback onExportPdf;
  final VoidCallback onShareDoc;
  final VoidCallback onSharePdf;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<bool> onVisualModeChanged;
  final ValueChanged<int> onFontSize;
  final ValueChanged<String> onTextColor;
  final ValueChanged<String> onHighlight;
  final ValueChanged<String> onAlignment;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrike;
  final VoidCallback onHeading;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onChecklist;
  final VoidCallback onQuote;
  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onDuplicate;
  final VoidCallback onLink;
  final VoidCallback onImage;
  final VoidCallback onImageSmaller;
  final VoidCallback onImageLarger;
  final VoidCallback onTable;
  final VoidCallback onRule;
  final VoidCallback onDateTime;
  final ValueChanged<WorkspaceLiveBlockType> onInsert;
  final VoidCallback onInsertTrainingTemplate;
  final VoidCallback onAddTrainingExercise;
  final VoidCallback onInsertTrainingGraphic;
  final VoidCallback? onAiAnalysis;
  final bool aiActive;

  @override
  Widget build(BuildContext context) {
    final primaryActions = <Widget>[
      _EditorMaterialToolButton(
        icon: Icons.undo_rounded,
        tooltip: 'Отменить',
        onTap: canUndo ? onUndo : null,
      ),
      _EditorMaterialToolButton(
        icon: Icons.redo_rounded,
        tooltip: 'Повторить',
        onTap: canRedo ? onRedo : null,
      ),
      const _EditorToolDivider(),
      _EditorFontSizeButton(onSelected: onFontSize),
      _EditorPaletteButton(
        icon: Icons.format_color_text_rounded,
        tooltip: 'Цвет текста',
        onSelected: onTextColor,
        colors: const <String>[
          '101814', '0B8F55', '315447', '2563EB', '7C3AED', 'B42318', 'B54708',
        ],
      ),
      _EditorPaletteButton(
        icon: Icons.format_color_fill_rounded,
        tooltip: 'Выделение цветом',
        onSelected: onHighlight,
        colors: const <String>[
          'EAF5EF', 'FFF1B8', 'FDE2E2', 'E5EDFF', 'EFE7FF', 'F2F4F7',
        ],
      ),
      _EditorAlignmentButton(onSelected: onAlignment),
      const _EditorToolDivider(),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.heading,
          tooltip: 'Заголовок',
          onTap: onHeading),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.bold,
          tooltip: 'Жирный',
          onTap: onBold),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.italic,
          tooltip: 'Курсив',
          onTap: onItalic),
      _EditorTextToolButton(
          label: 'U', tooltip: 'Подчёркнутый', onTap: onUnderline),
      _EditorTextToolButton(
          label: 'S̶', tooltip: 'Зачёркнутый', onTap: onStrike),
      const _EditorToolDivider(),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.bullets,
          tooltip: 'Список',
          onTap: onBullet),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.numbered,
          tooltip: 'Нумерованный список',
          onTap: onNumbered),
      _EditorTextToolButton(label: '☐', tooltip: 'Задача', onTap: onChecklist),
      _EditorToolButton(
          icon: SportotekaWorkspaceIconKind.quote,
          tooltip: 'Цитата',
          onTap: onQuote),
      const _EditorToolDivider(),
      _EditorMaterialToolButton(
          icon: Icons.link_rounded, tooltip: 'Ссылка', onTap: onLink),
      _EditorMaterialToolButton(
          icon: Icons.image_outlined, tooltip: 'Вставить фото', onTap: onImage),
      _EditorMaterialToolButton(
          icon: Icons.table_chart_outlined, tooltip: 'Таблица', onTap: onTable),
      _EditorInsertButton(
        onInsert: onInsert,
        onInsertTrainingTemplate: onInsertTrainingTemplate,
        onAddTrainingExercise: onAddTrainingExercise,
        onInsertTrainingGraphic: onInsertTrainingGraphic,
      ),
      if (onAiAnalysis != null) ...[
        const SizedBox(width: 3),
        _EditorAiButton(onTap: onAiAnalysis!, active: aiActive),
      ],
    ];

    final fullActions = <Widget>[
      ...primaryActions.take(2),
      const _EditorToolDivider(),
      _EditorFontSizeButton(onSelected: onFontSize),
      _EditorPaletteButton(
        icon: Icons.format_color_text_rounded,
        tooltip: 'Цвет текста',
        onSelected: onTextColor,
        colors: const <String>[
          '101814', '0B8F55', '315447', '2563EB', '7C3AED', 'B42318', 'B54708',
        ],
      ),
      _EditorPaletteButton(
        icon: Icons.format_color_fill_rounded,
        tooltip: 'Выделение цветом',
        onSelected: onHighlight,
        colors: const <String>[
          'EAF5EF', 'FFF1B8', 'FDE2E2', 'E5EDFF', 'EFE7FF', 'F2F4F7',
        ],
      ),
      _EditorAlignmentButton(onSelected: onAlignment),
      const _EditorToolDivider(),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.heading, tooltip: 'Заголовок', onTap: onHeading),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.bold, tooltip: 'Жирный', onTap: onBold),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.italic, tooltip: 'Курсив', onTap: onItalic),
      _EditorTextToolButton(label: 'U', tooltip: 'Подчёркнутый', onTap: onUnderline),
      _EditorTextToolButton(label: 'S̶', tooltip: 'Зачёркнутый', onTap: onStrike),
      const _EditorToolDivider(),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.bullets, tooltip: 'Список', onTap: onBullet),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.numbered, tooltip: 'Нумерованный список', onTap: onNumbered),
      _EditorTextToolButton(label: '☐', tooltip: 'Задача', onTap: onChecklist),
      _EditorToolButton(icon: SportotekaWorkspaceIconKind.quote, tooltip: 'Цитата', onTap: onQuote),
      const _EditorToolDivider(),
      _EditorMaterialToolButton(icon: Icons.content_copy_rounded, tooltip: 'Копировать', onTap: onCopy),
      _EditorMaterialToolButton(icon: Icons.content_cut_rounded, tooltip: 'Вырезать', onTap: onCut),
      _EditorMaterialToolButton(icon: Icons.content_paste_rounded, tooltip: 'Вставить', onTap: onPaste),
      _EditorMaterialToolButton(icon: Icons.select_all_rounded, tooltip: 'Выделить всё', onTap: onSelectAll),
      _EditorMaterialToolButton(icon: Icons.control_point_duplicate_rounded, tooltip: 'Дублировать выделение', onTap: onDuplicate),
      const _EditorToolDivider(),
      _EditorMaterialToolButton(icon: Icons.link_rounded, tooltip: 'Ссылка', onTap: onLink),
      _EditorMaterialToolButton(icon: Icons.image_outlined, tooltip: 'Вставить фото', onTap: onImage),
      _EditorMaterialToolButton(icon: Icons.photo_size_select_small_rounded, tooltip: 'Уменьшить ближайшее фото', onTap: onImageSmaller),
      _EditorMaterialToolButton(icon: Icons.photo_size_select_large_rounded, tooltip: 'Увеличить ближайшее фото', onTap: onImageLarger),
      _EditorMaterialToolButton(icon: Icons.table_chart_outlined, tooltip: 'Таблица', onTap: onTable),
      _EditorMaterialToolButton(icon: Icons.horizontal_rule_rounded, tooltip: 'Разделитель', onTap: onRule),
      _EditorMaterialToolButton(icon: Icons.event_outlined, tooltip: 'Дата и время', onTap: onDateTime),
      const _EditorToolDivider(),
      _EditorInsertButton(
        onInsert: onInsert,
        onInsertTrainingTemplate: onInsertTrainingTemplate,
        onAddTrainingExercise: onAddTrainingExercise,
        onInsertTrainingGraphic: onInsertTrainingGraphic,
      ),
      if (onAiAnalysis != null) ...[
        const SizedBox(width: 4),
        _EditorAiButton(onTap: onAiAnalysis!, active: aiActive),
      ],
    ];

    final actions = wordCompact ? primaryActions : fullActions;

    return IgnorePointer(
      ignoring: readOnly,
      child: Opacity(
        opacity: readOnly ? .48 : 1,
        child: Container(
          height: wordCompact ? 44 : (compact ? 49 : 54),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
                bottom: BorderSide(color: _WorkspaceDocumentEditorState._line)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 5),
              _EditorFileMenuButton(
                canSave: canSave,
                dirty: dirty,
                saving: saving,
                onSave: onSave,
                onExportDoc: onExportDoc,
                onExportPdf: onExportPdf,
                onShareDoc: onShareDoc,
                onSharePdf: onSharePdf,
              ),
              const SizedBox(width: 3),
              if (!compact && !wordCompact) ...[
                const SizedBox(width: 16),
                Text('ФОРМАТ',
                    style: AppTypography.menuGroup(
                        color: _WorkspaceDocumentEditorState._muted)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                      horizontal: compact || wordCompact ? 6 : 0,
                      vertical: wordCompact ? 2 : 5),
                  children: actions,
                ),
              ),
              if (wordCompact) ...[
                const SizedBox(width: 2),
                _EditorCompactMoreButton(
                  onCopy: onCopy,
                  onCut: onCut,
                  onPaste: onPaste,
                  onSelectAll: onSelectAll,
                  onDuplicate: onDuplicate,
                  onImageSmaller: onImageSmaller,
                  onImageLarger: onImageLarger,
                  onRule: onRule,
                  onDateTime: onDateTime,
                ),
                const SizedBox(width: 3),
                _EditorCompactSaveButton(
                  saving: saving,
                  dirty: dirty,
                  failed: failed,
                  enabled: canSave,
                  onSave: onSave,
                ),
              ],
              const SizedBox(width: 4),
              _EditorViewToggle(
                visualMode: visualMode,
                compact: compact || wordCompact,
                onChanged: onVisualModeChanged,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}



class _EditorFileMenuButton extends StatelessWidget {
  const _EditorFileMenuButton({
    required this.canSave,
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onExportDoc,
    required this.onExportPdf,
    required this.onShareDoc,
    required this.onSharePdf,
  });

  final bool canSave;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onExportDoc;
  final VoidCallback onExportPdf;
  final VoidCallback onShareDoc;
  final VoidCallback onSharePdf;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Файл',
      color: Colors.white,
      elevation: 12,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case 'save':
            onSave();
            break;
          case 'doc':
            onExportDoc();
            break;
          case 'pdf':
            onExportPdf();
            break;
          case 'share_doc':
            onShareDoc();
            break;
          case 'share_pdf':
            onSharePdf();
            break;
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'save',
          enabled: canSave && dirty && !saving,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.save_outlined, size: 18),
            title: Text('Сохранить в Sportoteka'),
            subtitle: Text('⌘S / Ctrl+S'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'doc',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.description_outlined, size: 18),
            title: Text('Сохранить как DOC'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'pdf',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.picture_as_pdf_outlined, size: 18),
            title: Text('Сохранить как PDF'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'share_doc',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.send_outlined, size: 18),
            title: Text('Отправить DOC'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'share_pdf',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.ios_share_rounded, size: 18),
            title: Text('Отправить PDF'),
          ),
        ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 16,
              color: Color(0xFF315447),
            ),
            const SizedBox(width: 5),
            Text(
              'Файл',
              style: AppTypography.captionMedium(
                color: const Color(0xFF315447),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 17,
              color: Color(0xFF667085),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCompactSaveButton extends StatelessWidget {
  const _EditorCompactSaveButton({
    required this.saving,
    required this.dirty,
    required this.failed,
    required this.enabled,
    required this.onSave,
  });

  final bool saving;
  final bool dirty;
  final bool failed;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String tooltip;
    if (saving) {
      icon = Icons.sync_rounded;
      color = const Color(0xFF0B8F55);
      tooltip = 'Сохраняется…';
    } else if (failed) {
      icon = Icons.cloud_off_rounded;
      color = const Color(0xFFB42318);
      tooltip = 'Не синхронизировано — нажмите, чтобы повторить';
    } else if (dirty) {
      icon = Icons.cloud_upload_outlined;
      color = const Color(0xFFB54708);
      tooltip = 'Есть изменения — сохранить (⌘S / Ctrl+S)';
    } else {
      icon = Icons.cloud_done_outlined;
      color = const Color(0xFF0B8F55);
      tooltip = 'Сохранено';
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled && !saving && (dirty || failed) ? onSave : null,
        child: SizedBox.square(
          dimension: 34,
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Color(0xFF0B8F55),
                    ),
                  )
                : Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _EditorCompactMoreButton extends StatelessWidget {
  const _EditorCompactMoreButton({
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onSelectAll,
    required this.onDuplicate,
    required this.onImageSmaller,
    required this.onImageLarger,
    required this.onRule,
    required this.onDateTime,
  });

  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onDuplicate;
  final VoidCallback onImageSmaller;
  final VoidCallback onImageLarger;
  final VoidCallback onRule;
  final VoidCallback onDateTime;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Ещё инструменты',
      color: Colors.white,
      elevation: 10,
      onSelected: (value) {
        switch (value) {
          case 'copy': onCopy(); break;
          case 'cut': onCut(); break;
          case 'paste': onPaste(); break;
          case 'all': onSelectAll(); break;
          case 'duplicate': onDuplicate(); break;
          case 'img-': onImageSmaller(); break;
          case 'img+': onImageLarger(); break;
          case 'rule': onRule(); break;
          case 'datetime': onDateTime(); break;
        }
      },
      itemBuilder: (_) => const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'copy', child: ListTile(dense: true, leading: Icon(Icons.content_copy_rounded, size: 18), title: Text('Копировать'))),
        PopupMenuItem(value: 'cut', child: ListTile(dense: true, leading: Icon(Icons.content_cut_rounded, size: 18), title: Text('Вырезать'))),
        PopupMenuItem(value: 'paste', child: ListTile(dense: true, leading: Icon(Icons.content_paste_rounded, size: 18), title: Text('Вставить'))),
        PopupMenuDivider(),
        PopupMenuItem(value: 'all', child: ListTile(dense: true, leading: Icon(Icons.select_all_rounded, size: 18), title: Text('Выделить всё'))),
        PopupMenuItem(value: 'duplicate', child: ListTile(dense: true, leading: Icon(Icons.control_point_duplicate_rounded, size: 18), title: Text('Дублировать'))),
        PopupMenuDivider(),
        PopupMenuItem(value: 'img-', child: ListTile(dense: true, leading: Icon(Icons.photo_size_select_small_rounded, size: 18), title: Text('Уменьшить фото'))),
        PopupMenuItem(value: 'img+', child: ListTile(dense: true, leading: Icon(Icons.photo_size_select_large_rounded, size: 18), title: Text('Увеличить фото'))),
        PopupMenuItem(value: 'rule', child: ListTile(dense: true, leading: Icon(Icons.horizontal_rule_rounded, size: 18), title: Text('Разделитель'))),
        PopupMenuItem(value: 'datetime', child: ListTile(dense: true, leading: Icon(Icons.event_outlined, size: 18), title: Text('Дата и время'))),
      ],
      child: const Tooltip(
        message: 'Ещё инструменты',
        child: SizedBox.square(
          dimension: 34,
          child: Center(child: Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF29332D))),
        ),
      ),
    );
  }
}

class _EditorFontSizeButton extends StatelessWidget {
  const _EditorFontSizeButton({required this.onSelected});
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const sizes = <int>[10, 12, 14, 16, 18, 20, 24, 28, 32, 40];
    return PopupMenuButton<int>(
      tooltip: 'Размер шрифта',
      color: Colors.white,
      elevation: 8,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final size in sizes)
          PopupMenuItem<int>(
            value: size,
            child: Text(
              '$size pt',
              style: AppTypography.body(color: const Color(0xFF101814))
                  .copyWith(fontSize: size.clamp(11, 20).toDouble()),
            ),
          ),
      ],
      child: Tooltip(
        message: 'Размер шрифта',
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '15',
                style: AppTypography.actionStrong(
                  color: const Color(0xFF29332D),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: Color(0xFF667085),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorPaletteButton extends StatelessWidget {
  const _EditorPaletteButton({
    required this.icon,
    required this.tooltip,
    required this.onSelected,
    required this.colors,
  });

  final IconData icon;
  final String tooltip;
  final ValueChanged<String> onSelected;
  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      color: Colors.white,
      elevation: 8,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final hex in colors)
          PopupMenuItem<String>(
            value: hex,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _workspaceHexColor(hex, Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD7DDD9)),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '#$hex',
                  style: AppTypography.captionMedium(
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(icon, size: 19, color: const Color(0xFF29332D)),
          ),
        ),
      ),
    );
  }
}

class _EditorAlignmentButton extends StatelessWidget {
  const _EditorAlignmentButton({required this.onSelected});
  final ValueChanged<String> onSelected;

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF29332D)),
          const SizedBox(width: 9),
          Text(
            label,
            style: AppTypography.action(color: const Color(0xFF29332D)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Выравнивание',
      color: Colors.white,
      elevation: 8,
      onSelected: onSelected,
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        _item('left', Icons.format_align_left_rounded, 'По левому краю'),
        _item('center', Icons.format_align_center_rounded, 'По центру'),
        _item('right', Icons.format_align_right_rounded, 'По правому краю'),
        _item('justify', Icons.format_align_justify_rounded, 'По ширине'),
      ],
      child: const Tooltip(
        message: 'Выравнивание',
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(
              Icons.format_align_left_rounded,
              size: 19,
              color: Color(0xFF29332D),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorViewToggle extends StatelessWidget {
  const _EditorViewToggle({
    required this.visualMode,
    required this.compact,
    required this.onChanged,
  });

  final bool visualMode;
  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EditorViewOption(
            icon: Icons.article_outlined,
            label: compact ? '' : 'Страница',
            active: visualMode,
            onTap: () => onChanged(true),
          ),
          _EditorViewOption(
            icon: Icons.code_rounded,
            label: compact ? '' : 'Текст',
            active: !visualMode,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _EditorViewOption extends StatelessWidget {
  const _EditorViewOption({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 8 : 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFF0B8F55) : const Color(0xFF758079),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.captionMedium(
                  color: active ? const Color(0xFF0B8F55) : const Color(0xFF758079),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportedSourceDocumentBlock extends StatelessWidget {
  const _ImportedSourceDocumentBlock({
    required this.filename,
    required this.extension,
    required this.sizeLabel,
    required this.onOpen,
  });

  final String filename;
  final String extension;
  final String sizeLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (extension.trim().isNotEmpty) extension.trim(),
      if (sizeLabel.trim().isNotEmpty) sizeLabel.trim(),
      'оригинал',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6EBDD)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE8E1)),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFF0B8F55),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.itemTitle(
                    color: const Color(0xFF101814),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: AppTypography.caption(
                    color: const Color(0xFF758079),
                  ),
                ),
              ],
            ),
          ),
          if (onOpen != null)
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 17,
              ),
              label: const Text('Открыть оригинал'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0B8F55),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorAiButton extends StatelessWidget {
  const _EditorAiButton({
    required this.onTap,
    required this.active,
  });

  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Открыть ИИ-анализ текущего документа',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE7F7ED) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFBCE8CD) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF0B8F55),
              ),
              const SizedBox(width: 6),
              Text(
                'AI анализ',
                style: AppTypography.actionStrong(
                  color: const Color(0xFF0B8F55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TrainingPlanInlineField extends StatefulWidget {
  const _TrainingPlanInlineField({
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.multiline = false,
    this.centered = false,
    this.hint,
  });

  final String value;
  final bool readOnly;
  final ValueChanged<String> onChanged;
  final bool multiline;
  final bool centered;
  final String? hint;

  @override
  State<_TrainingPlanInlineField> createState() => _TrainingPlanInlineFieldState();
}

class _TrainingPlanInlineFieldState extends State<_TrainingPlanInlineField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TrainingPlanInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset.clamp(0, widget.value.length).toInt(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      minLines: widget.multiline ? 2 : 1,
      maxLines: widget.multiline ? 5 : 1,
      textAlign: widget.centered ? TextAlign.center : TextAlign.left,
      style: AppTypography.body(color: const Color(0xFF101814)).copyWith(
        fontSize: 11.2,
        height: 1.25,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTypography.body(color: const Color(0xFF9AA39E)).copyWith(fontSize: 10.8),
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: widget.readOnly ? null : widget.onChanged,
    );
  }
}

class _EditorInsertButton extends StatelessWidget {
  const _EditorInsertButton({
    required this.onInsert,
    required this.onInsertTrainingTemplate,
    required this.onAddTrainingExercise,
    required this.onInsertTrainingGraphic,
  });

  final ValueChanged<WorkspaceLiveBlockType> onInsert;
  final VoidCallback onInsertTrainingTemplate;
  final VoidCallback onAddTrainingExercise;
  final VoidCallback onInsertTrainingGraphic;

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

    return PopupMenuButton<String>(
      tooltip: 'Вставить',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case 'training_template':
            onInsertTrainingTemplate();
            return;
          case 'training_exercise':
            onAddTrainingExercise();
            return;
          case 'training_graphic':
            onInsertTrainingGraphic();
            return;
        }

        if (!value.startsWith('live:')) return;
        final name = value.substring(5);
        for (final type in WorkspaceLiveBlockType.values) {
          if (type.name == name) {
            onInsert(type);
            return;
          }
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'training_template',
          child: _EditorInsertSpecialRow(
            icon: Icons.description_outlined,
            title: 'Шаблон план-конспекта',
            subtitle: 'Пустые графы + упражнение 1',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'training_exercise',
          child: _EditorInsertSpecialRow(
            icon: Icons.add_box_outlined,
            title: 'Добавить упражнение',
            subtitle: 'Автоматически: 4, 5, 6 и далее',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'training_graphic',
          child: _EditorInsertSpecialRow(
            icon: Icons.draw_outlined,
            title: 'Схема из графического редактора',
            subtitle: 'Выбрать сохранённую схему Sportoteka',
          ),
        ),
        const PopupMenuDivider(),
        for (final type in entries)
          PopupMenuItem<String>(
            value: 'live:${type.name}',
            child: Row(
              children: [
                SportotekaWorkspaceIcon(
                  kind: _editorIconForType(type),
                  size: 19,
                  color: const Color(0xFF0B8F55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editorTitleForType(type),
                        style: AppTypography.menuTitle(
                          color: const Color(0xFF101814),
                        ),
                      ),
                      Text(
                        _editorSubtitleForType(type),
                        style: AppTypography.caption(
                          color: const Color(0xFF758079),
                        ),
                      ),
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
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF0B8F55),
                ),
                const SizedBox(width: 5),
                Text(
                  'Вставить',
                  style: AppTypography.actionStrong(
                    color: const Color(0xFF0B8F55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorInsertSpecialRow extends StatelessWidget {
  const _EditorInsertSpecialRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5EF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0B8F55)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.menuTitle(
                  color: const Color(0xFF101814),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: AppTypography.caption(
                  color: const Color(0xFF758079),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

SportotekaWorkspaceIconKind _editorIconForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan:
      return SportotekaWorkspaceIconKind.plans;
    case WorkspaceLiveBlockType.match:
      return SportotekaWorkspaceIconKind.matches;
    case WorkspaceLiveBlockType.training:
      return SportotekaWorkspaceIconKind.trainings;
    case WorkspaceLiveBlockType.player:
      return SportotekaWorkspaceIconKind.players;
    case WorkspaceLiveBlockType.tracker:
      return SportotekaWorkspaceIconKind.tracker;
    case WorkspaceLiveBlockType.testing:
      return SportotekaWorkspaceIconKind.testing;
    case WorkspaceLiveBlockType.video:
      return SportotekaWorkspaceIconKind.video;
    case WorkspaceLiveBlockType.document:
      return SportotekaWorkspaceIconKind.documents;
  }
}

String _editorTitleForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan:
      return 'План-конспект';
    case WorkspaceLiveBlockType.match:
      return 'Матч';
    case WorkspaceLiveBlockType.training:
      return 'Тренировка';
    case WorkspaceLiveBlockType.player:
      return 'Игрок';
    case WorkspaceLiveBlockType.tracker:
      return 'Tracker';
    case WorkspaceLiveBlockType.testing:
      return 'Тестирование';
    case WorkspaceLiveBlockType.video:
      return 'Видео';
    case WorkspaceLiveBlockType.document:
      return 'Документ';
  }
}

String _editorSubtitleForType(WorkspaceLiveBlockType type) {
  switch (type) {
    case WorkspaceLiveBlockType.plan:
      return 'Живой план + PDF snapshot';
    case WorkspaceLiveBlockType.match:
      return 'Соперник, счёт и дата';
    case WorkspaceLiveBlockType.training:
      return 'Событие, место и команда';
    case WorkspaceLiveBlockType.player:
      return 'Карточка игрока';
    case WorkspaceLiveBlockType.tracker:
      return 'GPS, скорость и ЧСС';
    case WorkspaceLiveBlockType.testing:
      return 'Реальная тестовая сессия';
    case WorkspaceLiveBlockType.video:
      return 'Видеораздел / материал';
    case WorkspaceLiveBlockType.document:
      return 'Документ из архива';
  }
}

class _EditorLiveBlockButton extends StatelessWidget {
  const _EditorLiveBlockButton(
      {required this.title,
      required this.subtitle,
      required this.onTap,
      this.iconKind = SportotekaWorkspaceIconKind.plans});
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
              SportotekaWorkspaceIcon(
                  kind: iconKind, size: 22, color: const Color(0xFF0B8F55)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.menuTitle(
                            color: const Color(0xFF101814))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.caption(
                            color: const Color(0xFF758079))),
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
  const _EditorToolButton(
      {required this.icon, required this.tooltip, required this.onTap});

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

class _EditorMaterialToolButton extends StatelessWidget {
  const _EditorMaterialToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: Icon(
              icon,
              size: 19,
              color: enabled
                  ? const Color(0xFF29332D)
                  : const Color(0xFFB4BBB7),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorTextToolButton extends StatelessWidget {
  const _EditorTextToolButton(
      {required this.label, required this.tooltip, required this.onTap});

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
          child: Center(
              child: Text(label,
                  style:
                      AppTypography.itemTitle(color: const Color(0xFF29332D)))),
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
  const _EditorHeaderButton(
      {required this.icon, required this.tooltip, required this.onTap});

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
  const _EditorSaveState(
      {required this.compact,
      required this.saving,
      required this.dirty,
      required this.failed,
      required this.readOnly});

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
      return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
                Expanded(
                    child: Text(title,
                        style: AppTypography.menuTitle(
                            color: const Color(0xFF263129)))),
                const SportotekaWorkspaceIcon(
                    kind: SportotekaWorkspaceIconKind.chevronRight,
                    size: 15,
                    color: Color(0xFF78837C)),
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
      decoration: BoxDecoration(
          color: const Color(0xFFF0F4F1),
          borderRadius: BorderRadius.circular(999)),
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
            Color(0xFFC4DED0),
            Color(0xFF8FC2A6),
            Color(0xFFDCECE3),
            Color(0xFF75B492),
            Color(0xFF0B8F55),
            Color(0xFFAED3BF),
            Color(0xFFD5E8DD),
            Color(0xFF66AA86),
            Color(0xFFBADBC9),
          ];
          return Container(
            width: dot,
            height: dot,
            decoration:
                BoxDecoration(color: colors[index], shape: BoxShape.circle),
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
              color: index == 1
                  ? const Color(0xFF0B8F55)
                  : const Color(0xFFAED3BF),
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


class _WorkspaceTrainingGraphicsPickerPane extends StatefulWidget {
  const _WorkspaceTrainingGraphicsPickerPane({
    required this.clubId,
    required this.teamId,
    required this.clubName,
    required this.teamName,
    required this.preselectedIds,
    required this.onClose,
    required this.onSelected,
  });

  final int clubId;
  final int teamId;
  final String clubName;
  final String teamName;
  final List<int> preselectedIds;
  final VoidCallback onClose;
  final Future<void> Function(List<int> ids) onSelected;

  @override
  State<_WorkspaceTrainingGraphicsPickerPane> createState() =>
      _WorkspaceTrainingGraphicsPickerPaneState();
}

class _WorkspaceTrainingGraphicsPickerPaneState
    extends State<_WorkspaceTrainingGraphicsPickerPane> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE6EAE7);
  static const _soft = Color(0xFFF7F9F8);

  final TextEditingController _search = TextEditingController();
  final Set<int> _selected = <int>{};
  final List<Map<String, dynamic>> _crumbs = <Map<String, dynamic>>[];

  bool _loading = true;
  String? _error;
  List<dynamic> _tree = <dynamic>[];
  List<Map<String, dynamic>> _folders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _graphics = <Map<String, dynamic>>[];
  int? _parentId;
  String _parentTitle = 'Все схемы';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.preselectedIds.where((id) => id > 0));
    _crumbs.add(<String, dynamic>{'id': null, 'title': 'Все схемы'});
    _search.addListener(_loadCurrent);
    _loadRoot();
  }

  @override
  void dispose() {
    _search.removeListener(_loadCurrent);
    _search.dispose();
    super.dispose();
  }

  int _asInt(dynamic raw) =>
      raw is int ? raw : int.tryParse('${raw ?? ''}'.trim()) ?? 0;

  String _asString(dynamic raw) {
    final value = '${raw ?? ''}'.trim();
    return value == 'null' ? '' : value;
  }

  String _absoluteImage(dynamic raw) {
    final value = _asString(raw);
    if (value.isEmpty) return '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    return 'https://sportotekaapp.ru/$value';
  }

  List<Map<String, dynamic>> _extractFolders(
    List<dynamic> tree,
    int? parentId,
  ) {
    final result = <Map<String, dynamic>>[];

    void walk(List<dynamic> nodes) {
      for (final raw in nodes) {
        if (raw is! Map) continue;
        final node = Map<String, dynamic>.from(raw);
        final nodeParent = _asInt(node['parent_id']);
        if (nodeParent == (parentId ?? 0)) result.add(node);

        final children = node['children'];
        if (children is List && children.isNotEmpty) walk(children);
      }
    }

    walk(tree);
    return result;
  }

  Future<void> _loadRoot() async {
    if (widget.clubId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Не удалось определить клуб.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await PlanFoldersApi.list(clubId: widget.clubId);
      if (response['success'] != true) {
        throw Exception(
          '${response['message'] ?? 'Не удалось загрузить папки'}',
        );
      }
      _tree = (response['tree'] as List?) ?? <dynamic>[];
      await _loadCurrent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadCurrent() async {
    if (!mounted || widget.clubId <= 0) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await TrainingGraphicsApi.list(
        clubId: widget.clubId,
        teamId: widget.teamId,
        folderId: _parentId ?? 0,
      );

      if (response['success'] != true) {
        throw Exception(
          '${response['message'] ?? 'Не удалось загрузить схемы'}',
        );
      }

      final query = _search.text.trim().toLowerCase();
      var folders = _extractFolders(_tree, _parentId);
      var graphics = ((response['items'] as List?) ?? <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: true);

      if (query.isNotEmpty) {
        folders = folders
            .where((item) =>
                _asString(item['title']).toLowerCase().contains(query))
            .toList(growable: true);
        graphics = graphics
            .where((item) =>
                _asString(item['title']).toLowerCase().contains(query))
            .toList(growable: true);
      }

      if (!mounted) return;
      setState(() {
        _folders = folders;
        _graphics = graphics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _enterFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id <= 0) return;
    setState(() {
      _parentId = id;
      _parentTitle = _asString(folder['title']).isEmpty
          ? 'Папка'
          : _asString(folder['title']);
      _crumbs.add(<String, dynamic>{
        'id': id,
        'title': _parentTitle,
      });
      _search.clear();
    });
    await _loadCurrent();
  }

  Future<void> _goToCrumb(int index) async {
    if (index < 0 || index >= _crumbs.length) return;
    final crumb = _crumbs[index];
    final id = _asInt(crumb['id']);
    setState(() {
      _parentId = id <= 0 ? null : id;
      _parentTitle = _asString(crumb['title']);
      _crumbs.removeRange(index + 1, _crumbs.length);
      _search.clear();
    });
    await _loadCurrent();
  }

  void _toggle(int id) {
    if (id <= 0) return;
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.length;
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.draw_outlined,
                    size: 17,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Схемы · Sportoteka OS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.menuTitle(color: _text),
                      ),
                      Text(
                        widget.teamName.trim().isEmpty
                            ? widget.clubName
                            : '${widget.clubName} · ${widget.teamName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
            decoration: const BoxDecoration(
              color: _soft,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _search,
                    style: AppTypography.body(color: _text).copyWith(
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Найти схему',
                      hintStyle:
                          AppTypography.caption(color: const Color(0xFF98A09B)),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: _muted,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 26,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _crumbs.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: _muted,
                      ),
                    ),
                    itemBuilder: (_, index) {
                      final title = _asString(_crumbs[index]['title']);
                      return InkWell(
                        onTap: () => _goToCrumb(index),
                        borderRadius: BorderRadius.circular(7),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            title,
                            style: AppTypography.captionMedium(
                              color: index == _crumbs.length - 1
                                  ? _green
                                  : _muted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _green,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTypography.body(color: _muted),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _loadRoot,
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 92),
                        children: [
                          if (_folders.isNotEmpty) ...[
                            Text(
                              'ПАПКИ',
                              style: AppTypography.menuGroup(color: _muted),
                            ),
                            const SizedBox(height: 6),
                            for (final folder in _folders)
                              _WorkspaceGraphicsFolderTile(
                                title: _asString(folder['title']),
                                onTap: () => _enterFolder(folder),
                              ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'СХЕМЫ',
                                  style:
                                      AppTypography.menuGroup(color: _muted),
                                ),
                              ),
                              Text(
                                '${_graphics.length}',
                                style: AppTypography.caption(color: _muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_graphics.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _soft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'В этой папке схем пока нет.',
                                style: AppTypography.body(color: _muted),
                              ),
                            )
                          else
                            for (final graphic in _graphics)
                              _WorkspaceGraphicSelectTile(
                                title: _asString(graphic['title']).isEmpty
                                    ? 'Схема'
                                    : _asString(graphic['title']),
                                previewUrl: _absoluteImage(
                                  graphic['preview_url'] ??
                                      graphic['preview'] ??
                                      graphic['image_url'],
                                ),
                                selected:
                                    _selected.contains(_asInt(graphic['id'])),
                                onTap: () => _toggle(_asInt(graphic['id'])),
                              ),
                        ],
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCount == 0
                        ? 'Выберите схему'
                        : 'Выбрано: $selectedCount',
                    style: AppTypography.captionMedium(color: _muted),
                  ),
                ),
                FilledButton.icon(
                  onPressed: selectedCount == 0
                      ? null
                      : () => widget.onSelected(
                            _selected.toList(growable: true),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE7ECE9),
                    disabledForegroundColor: const Color(0xFF98A09B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Прикрепить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceGraphicsFolderTile extends StatelessWidget {
  const _WorkspaceGraphicsFolderTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 44,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 18,
                color: Color(0xFF0B8F55),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title.isEmpty ? 'Папка' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(color: const Color(0xFF101814)),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Color(0xFF758079),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceGraphicSelectTile extends StatelessWidget {
  const _WorkspaceGraphicSelectTile({
    required this.title,
    required this.previewUrl,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String previewUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0B8F55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF5EF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? green : const Color(0xFFE6EAE7),
              width: selected ? 1.1 : .75,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: previewUrl.isEmpty
                    ? const Icon(
                        Icons.draw_outlined,
                        color: Color(0xFF758079),
                      )
                    : Image.network(
                        previewUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.draw_outlined,
                          color: Color(0xFF758079),
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.menuTitle(
                    color: const Color(0xFF101814),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? green : const Color(0xFFA3ABA5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
