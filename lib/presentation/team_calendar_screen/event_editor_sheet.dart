import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'team_calendar_models.dart';


Future<TeamEvent?> showEventEditorWindow(
  BuildContext context, {
  required Color primary,
  required int teamId,
  required int clubId,
  required int createdBy,
  required DateTime initialDateTime,
  TeamEvent? initial,
  Function(TeamEvent)? onEventAdded,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<TeamEvent?>();
  late OverlayEntry entry;

  void close([TeamEvent? result]) {
    if (!completer.isCompleted) completer.complete(result);
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _EventEditorFloatingWindow(
      primary: primary,
      teamId: teamId,
      clubId: clubId,
      createdBy: createdBy,
      initialDateTime: initialDateTime,
      initial: initial,
      onEventAdded: onEventAdded,
      onClose: close,
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class EventEditorSheet extends StatefulWidget {
  final Color primary;
  final int teamId;
  final int clubId;
  final int createdBy;
  final DateTime initialDateTime;
  final TeamEvent? initial;
  final Function(TeamEvent)? onEventAdded;
  final ValueChanged<TeamEvent>? onSubmit;
  final VoidCallback? onCancel;
  final bool embedded;

  const EventEditorSheet({
    super.key,
    required this.primary,
    required this.teamId,
    required this.clubId,
    required this.createdBy,
    required this.initialDateTime,
    this.initial,
    this.onEventAdded,
    this.onSubmit,
    this.onCancel,
    this.embedded = false,
  });

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  late final TextEditingController titleC;
  late final TextEditingController locationC;
  late final TextEditingController notesC;

  late TeamEventType type;
  late DateTime start;
  DateTime? end;
  bool _windowMaximized = false;
  bool _windowMinimized = false;

  // Focus + autoscroll
  final FocusNode _titleF = FocusNode();
  final FocusNode _locationF = FocusNode();
  final FocusNode _notesF = FocusNode();

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();

  ScrollController? _sheetScrollCtrl;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;

    titleC = TextEditingController(text: init?.title ?? "");
    locationC = TextEditingController(text: init?.location ?? "");
    notesC = TextEditingController(text: init?.notes ?? "");

    type = init?.type ?? TeamEventType.training;
    start = init?.startAt ?? widget.initialDateTime;
    end = init?.endAt;

    if (widget.initial == null) {
      if (start.hour == 0 && start.minute == 0) {
        start = DateTime(start.year, start.month, start.day, 18, 0);
      }
      end ??= start.add(const Duration(minutes: 90));
    }

    _titleF.addListener(() => _onFocus(_titleF, _titleKey));
    _locationF.addListener(() => _onFocus(_locationF, _locationKey));
    _notesF.addListener(() => _onFocus(_notesF, _notesKey));
  }

  @override
  void dispose() {
    titleC.dispose();
    locationC.dispose();
    notesC.dispose();

    _titleF.dispose();
    _locationF.dispose();
    _notesF.dispose();

    super.dispose();
  }

  void _onFocus(FocusNode node, GlobalKey key) {
    if (!node.hasFocus) return;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.18,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _pickStart() async {
    FocusScope.of(context).unfocus();

    final d = await showSportotekaDatePicker(
      context,
      primary: widget.primary,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: start,
      title: 'Дата начала',
    );
    if (d == null) return;

    final t = await showSportotekaTimePicker(
      context,
      primary: widget.primary,
      initial: TimeOfDay.fromDateTime(start),
      title: "Время начала",
      minuteStep5: true,
    );
    if (t == null) return;

    final newStart = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      start = newStart;
      if (end != null && end!.isBefore(start)) {
        end = start.add(const Duration(minutes: 90));
      }
    });
  }

  Future<void> _pickEnd() async {
    FocusScope.of(context).unfocus();

    final base = end ?? start.add(const Duration(minutes: 90));

    final d = await showSportotekaDatePicker(
      context,
      primary: widget.primary,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: base,
      title: 'Дата окончания',
    );
    if (d == null) return;

    final t = await showSportotekaTimePicker(
      context,
      primary: widget.primary,
      initial: TimeOfDay.fromDateTime(base),
      title: "Время окончания",
      minuteStep5: true,
    );
    if (t == null) return;

    setState(() {
      end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _copyStartToEnd() {
    setState(() {
      end = start.add(const Duration(minutes: 90));
    });
  }

  Future<bool> _validate() async {
    final title = titleC.text.trim();
    if (title.isEmpty) {
      Get.snackbar("Ошибка", "Введите название",
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (end != null && end!.isBefore(start)) {
      Get.snackbar("Ошибка", "Окончание раньше начала",
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  TeamEvent _createEvent() {
    return TeamEvent(
      id: widget.initial?.id ?? 0,
      teamId: widget.teamId,
      clubId: widget.clubId,
      type: type,
      title: titleC.text.trim(),
      startAt: start,
      endAt: end,
      location: locationC.text.trim(),
      notes: notesC.text.trim(),
    );
  }

  void _finish(TeamEvent event) {
    if (widget.onSubmit != null) {
      widget.onSubmit!(event);
      return;
    }
    Navigator.pop<TeamEvent>(context, event);
  }

  void _cancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
      return;
    }
    Navigator.pop(context);
  }

  void _submitAndClose() async {
    if (await _validate()) {
      final ev = _createEvent();
      _finish(ev);
    }
  }

  void _submitAndAddAnother() async {
    if (await _validate()) {
      final ev = _createEvent();
      
      // Вызываем callback, если он есть
      if (widget.onEventAdded != null) {
        widget.onEventAdded!(ev);
      }
      
      // Очищаем форму для следующего события
      setState(() {
        titleC.clear();
        locationC.clear();
        notesC.clear();
        type = TeamEventType.training;
        start = DateTime(start.year, start.month, start.day, 18, 0);
        end = start.add(const Duration(minutes: 90));
      });
      
      // Показываем уведомление
      Get.snackbar(
        "Успешно", 
        "Событие добавлено. Можно добавить ещё",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      // Фокусируемся на поле названия для удобства
      FocusScope.of(context).requestFocus(_titleF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom;
    final size = media.size;

    if (widget.embedded) {
      return Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 76 + viewInsets),
                child: _buildAdaptiveFormContent(
                  scrollController: null,
                  viewInsets: viewInsets,
                  showSheetHeader: false,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomPodium(
                  bottomLift: viewInsets,
                  primary: widget.primary,
                  buttonText: widget.initial == null ? 'Добавить' : 'Сохранить',
                  onPressed: widget.initial == null
                      ? _submitAndClose
                      : () async {
                          if (await _validate()) {
                            _finish(_createEvent());
                          }
                        },
                  onAddAnother: widget.initial == null && widget.onEventAdded != null ? _submitAndAddAnother : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final windowWidth = _windowMaximized ? size.width - 28 : math.min(920.0, size.width - 24);
    final windowHeight = _windowMaximized ? size.height - 28 : math.min(760.0, size.height - 36 - viewInsets);
    final title = widget.initial == null ? 'Добавить событие' : 'Редактировать событие';

    if (_windowMinimized) {
      return Material(
        color: Colors.transparent,
        child: SizedBox(
          height: size.height,
          width: size.width,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _CmrMinimizedPill(
                  icon: Icons.calendar_month_rounded,
                  title: title,
                  onRestore: () => setState(() => _windowMinimized = false),
                  onClose: _cancel,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: size.height,
        width: size.width,
        child: SafeArea(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: windowWidth,
              height: windowHeight,
              margin: EdgeInsets.only(bottom: viewInsets),
              child: _CmrWindowFrame(
                icon: Icons.calendar_month_rounded,
                title: title,
                subtitle: formatSqlDateTime(start),
                maximized: _windowMaximized,
                primary: widget.primary,
                onClose: _cancel,
                onMinimize: () => setState(() => _windowMinimized = true),
                onToggleMaximize: () => setState(() => _windowMaximized = !_windowMaximized),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: _buildAdaptiveFormContent(
                          scrollController: null,
                          viewInsets: viewInsets,
                          showSheetHeader: false,
                        ),
                      ),
                    ),
                    _BottomPodium(
                      bottomLift: 0,
                      primary: widget.primary,
                      buttonText: widget.initial == null ? 'Добавить' : 'Сохранить',
                      onPressed: widget.initial == null
                          ? _submitAndClose
                          : () async {
                              if (await _validate()) {
                                _finish(_createEvent());
                              }
                            },
                      onAddAnother: widget.initial == null && widget.onEventAdded != null ? _submitAndAddAnother : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _fieldTextStyle => const TextStyle(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: ['SF Pro Text', 'Inter', 'Roboto', 'Arial'],
        fontSize: 12.0,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
        letterSpacing: -0.08,
      );

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: ['SF Pro Text', 'Inter', 'Roboto', 'Arial'],
        fontSize: 10.8,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        height: 1.05,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: ['SF Pro Text', 'Inter', 'Roboto', 'Arial'],
        fontSize: 10.6,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildAdaptiveFormContent({
    required ScrollController? scrollController,
    required double viewInsets,
    required bool showSheetHeader,
  }) {
    final header = showSheetHeader
        ? <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null ? "Добавить событие" : "Редактировать",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _cancel(),
                  child: const Text("Закрыть"),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]
        : const <Widget>[];

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;

        if (wide) {
          return ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ...header,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: [
                        _eventTypeBlock(compact: false),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _titleKey,
                          child: _card(
                            child: TextField(
                              focusNode: _titleF,
                              controller: titleC,
                              style: _fieldTextStyle,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_locationF),
                              decoration: _fieldDecoration('Название события', 'Например: U16 / УТЗ / Матч'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _locationKey,
                          child: _card(
                            child: TextField(
                              focusNode: _locationF,
                              controller: locationC,
                              style: _fieldTextStyle,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_notesF),
                              decoration: _fieldDecoration('Место', 'Стадион / зал / поле'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        _timeBlock(),
                        const SizedBox(height: 8),
                        KeyedSubtree(
                          key: _notesKey,
                          child: _card(
                            child: TextField(
                              focusNode: _notesF,
                              controller: notesC,
                              style: _fieldTextStyle,
                              minLines: 4,
                              maxLines: 6,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                              decoration: _fieldDecoration('Примечание', 'Задачи, инвентарь, важные детали'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return ListView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            ...header,
            _eventTypeBlock(compact: true),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _titleKey,
              child: _card(
                child: TextField(
                  focusNode: _titleF,
                  controller: titleC,
                  style: _fieldTextStyle,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_locationF),
                  decoration: _fieldDecoration('Название события', 'Например: U16 / УТЗ / Матч'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _timeBlock(),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _locationKey,
              child: _card(
                child: TextField(
                  focusNode: _locationF,
                  controller: locationC,
                  style: _fieldTextStyle,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesF),
                  decoration: _fieldDecoration('Место', 'Стадион / зал / поле'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _notesKey,
              child: _card(
                child: TextField(
                  focusNode: _notesF,
                  controller: notesC,
                  style: _fieldTextStyle,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: _fieldDecoration('Примечание', 'Необязательно'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _eventTypeBlock({required bool compact}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final half = (c.maxWidth - 10) / 2;
          final full = c.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chipSmart(TeamEventType.training, "Тренировка", maxWidth: half),
              _chipSmart(TeamEventType.leagueMatch, "Чемпионат", maxWidth: half),
              _chipSmart(
                TeamEventType.friendlyMatch,
                "Товарищеские игры",
                maxWidth: compact ? full : half,
              ),
              _chipSmart(
                TeamEventType.theory,
                "Теоретические занятия",
                maxWidth: compact ? full : half,
              ),
              _chipSmart(TeamEventType.gym, "ОФП / Зал", maxWidth: half),
              _chipSmart(TeamEventType.dayOff, "Выходной", maxWidth: half),
            ],
          );
        },
      ),
    );
  }

  Widget _timeBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Время",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.0,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _pickTile(
                  title: "Начало",
                  value: formatSqlDateTime(start),
                  icon: Icons.play_arrow_rounded,
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pickTile(
                  title: "Конец",
                  value: end == null ? "не задано" : formatSqlDateTime(end!),
                  icon: Icons.stop_rounded,
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 2,
            children: [
              TextButton(
                onPressed: () => setState(() => end = null),
                child: const Text("Без конца"),
              ),
              TextButton(
                onPressed: _copyStartToEnd,
                child: const Text("+90 минут"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipSmart(
    TeamEventType t,
    String text, {
    required double maxWidth,
  }) {
    final c = eventTypeColor(t);
    final active = type == t;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => type = t);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: active ? c.withOpacity(0.18) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? c : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10.4,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _pickTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          FocusScope.of(context).unfocus();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 10.2,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.4),
                    ),
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



class _EventEditorFloatingWindow extends StatefulWidget {
  final Color primary;
  final int teamId;
  final int clubId;
  final int createdBy;
  final DateTime initialDateTime;
  final TeamEvent? initial;
  final Function(TeamEvent)? onEventAdded;
  final ValueChanged<TeamEvent?> onClose;

  const _EventEditorFloatingWindow({
    required this.primary,
    required this.teamId,
    required this.clubId,
    required this.createdBy,
    required this.initialDateTime,
    required this.initial,
    required this.onEventAdded,
    required this.onClose,
  });

  @override
  State<_EventEditorFloatingWindow> createState() => _EventEditorFloatingWindowState();
}

class _EventEditorFloatingWindowState extends State<_EventEditorFloatingWindow> {
  bool _maximized = false;
  bool _minimized = false;
  Offset? _position;

  String get _title => widget.initial == null ? 'Добавить событие' : 'Редактировать событие';

  void _submit(TeamEvent event) => widget.onClose(event);
  void _close() => widget.onClose(null);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final insets = media.viewInsets.bottom;
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;
    final compact = size.width < 720;

    if (_minimized) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 14,
                bottom: 14,
                child: _CmrMinimizedPill(
                  icon: Icons.edit_calendar_rounded,
                  title: _title,
                  onRestore: () => setState(() => _minimized = false),
                  onClose: _close,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final width = _maximized || compact ? size.width - 24 : math.min(820.0, size.width - 36);
    final height = _maximized || compact ? size.height - safeTop - safeBottom - 24 - insets : math.min(650.0, size.height - safeTop - safeBottom - 40 - insets);
    final defaultLeft = (size.width - width) / 2;
    final defaultTop = safeTop + math.max(12.0, (size.height - safeTop - safeBottom - height - insets) / 2);
    final pos = _maximized || compact ? Offset(12, safeTop + 12) : (_position ?? Offset(defaultLeft, defaultTop));
    final double left = pos.dx.clamp(8.0, math.max(8.0, size.width - width - 8)).toDouble();
    final double top = pos.dy.clamp(safeTop + 8.0, math.max(safeTop + 8.0, size.height - height - safeBottom - insets - 8)).toDouble();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: _CmrWindowFrame(
                icon: Icons.edit_calendar_rounded,
                title: _title,
                subtitle: formatSqlDateTime(widget.initial?.startAt ?? widget.initialDateTime),
                maximized: _maximized || compact,
                primary: widget.primary,
                onClose: _close,
                onMinimize: () => setState(() => _minimized = true),
                onToggleMaximize: compact ? () {} : () => setState(() => _maximized = !_maximized),
                onHeaderDragUpdate: (_maximized || compact)
                    ? null
                    : (details) {
                        setState(() {
                          _position = Offset(left + details.delta.dx, top + details.delta.dy);
                        });
                      },
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: EventEditorSheet(
                          primary: widget.primary,
                          teamId: widget.teamId,
                          clubId: widget.clubId,
                          createdBy: widget.createdBy,
                          initialDateTime: widget.initialDateTime,
                          initial: widget.initial,
                          onEventAdded: widget.onEventAdded,
                          onSubmit: _submit,
                          onCancel: _close,
                          embedded: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> showSportotekaDatePicker(
  BuildContext context, {
  required Color primary,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Выберите дату',
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<DateTime?>();
  late OverlayEntry entry;

  void close(DateTime? result) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(null),
              child: Container(color: Colors.black.withOpacity(.14)),
            ),
          ),
          Positioned.fill(
            child: _SportotekaDatePickerWindow(
              primary: primary,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              title: title,
              onClose: close,
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class _SportotekaDatePickerWindow extends StatefulWidget {
  final Color primary;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final ValueChanged<DateTime?> onClose;

  const _SportotekaDatePickerWindow({
    required this.primary,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.onClose,
  });

  @override
  State<_SportotekaDatePickerWindow> createState() => _SportotekaDatePickerWindowState();
}

class _SportotekaDatePickerWindowState extends State<_SportotekaDatePickerWindow> {
  late DateTime _visibleMonth;
  late DateTime _selected;

  static const _months = <String>[
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];
  static const _week = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _enabled(DateTime d) {
    final x = _dateOnly(d);
    return !x.isBefore(_dateOnly(widget.firstDate)) && !x.isAfter(_dateOnly(widget.lastDate));
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<DateTime> _gridDays() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(376.0, media.size.width - 24);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: width,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6EAEE), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 30, spreadRadius: -16, offset: const Offset(0, 18))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE9EDF2), width: 1))),
                  child: Row(
                    children: [
                      _RoundWindowButton(icon: Icons.close_rounded, onTap: () => widget.onClose(null)),
                      const SizedBox(width: 8),
                      Container(width: 30, height: 30, decoration: BoxDecoration(color: Color.alphaBlend(widget.primary.withOpacity(.10), Colors.white), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.primary.withOpacity(.18))), child: Icon(Icons.calendar_today_rounded, color: widget.primary, size: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.title, style: const TextStyle(color: Color(0xFF111827), fontSize: 12.4, fontWeight: FontWeight.w800, height: 1.05))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      _RoundWindowButton(icon: Icons.chevron_left_rounded, onTap: () => _shiftMonth(-1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: Text('${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}', style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -.1)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoundWindowButton(icon: Icons.chevron_right_rounded, onTap: () => _shiftMonth(1)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: _week.map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 9.8, fontWeight: FontWeight.w800, color: Color(0xFF8A94A3)))))).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 42,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5),
                    itemBuilder: (context, index) {
                      final d = _gridDays()[index];
                      final currentMonth = d.month == _visibleMonth.month;
                      final enabled = _enabled(d);
                      final selected = _sameDay(d, _selected);
                      final today = _sameDay(d, DateTime.now());
                      final fg = !enabled
                          ? const Color(0xFFC4CAD3)
                          : selected
                              ? Colors.white
                              : currentMonth
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFB2BAC5);
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: enabled ? () => setState(() => _selected = _dateOnly(d)) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          decoration: BoxDecoration(
                            color: selected ? widget.primary : (today ? Color.alphaBlend(widget.primary.withOpacity(.07), Colors.white) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? widget.primary : (today ? widget.primary.withOpacity(.20) : const Color(0xFFE9EDF2)), width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Text('${d.day}', style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: fg, height: 1)),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE9EDF2), width: 1))),
                  child: Row(
                    children: [
                      Expanded(child: _OutlineSportButton(text: 'Сегодня', onTap: () => setState(() { final now = DateTime.now(); _selected = DateTime(now.year, now.month, now.day); _visibleMonth = DateTime(now.year, now.month); }), primary: widget.primary)),
                      const SizedBox(width: 8),
                      Expanded(child: _PrimarySportButton(text: 'Выбрать', onTap: () => widget.onClose(_selected), primary: widget.primary)),
                    ],
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

class _CmrWindowFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool maximized;
  final Color primary;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final Widget child;
  final GestureDragUpdateCallback? onHeaderDragUpdate;

  const _CmrWindowFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.maximized,
    required this.primary,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.child,
    this.onHeaderDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(maximized ? 20 : 26);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFE6EAEE), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 34,
              spreadRadius: -18,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: onHeaderDragUpdate,
              child: Container(
                height: 50,
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE9EDF2), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _RoundWindowButton(icon: Icons.close_rounded, onTap: onClose),
                    const SizedBox(width: 7),
                    _RoundWindowButton(icon: Icons.remove_rounded, onTap: onMinimize),
                    const SizedBox(width: 7),
                    _RoundWindowButton(
                      icon: maximized
                          ? Icons.close_fullscreen_rounded
                          : Icons.open_in_full_rounded,
                      onTap: onToggleMaximize,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(primary.withOpacity(.10), Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primary.withOpacity(.20)),
                      ),
                      child: Icon(icon, color: primary, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.8,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.4,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                              letterSpacing: -.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _RoundWindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundWindowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF6B7280), size: 14),
      ),
    );
  }
}

class _CmrMinimizedPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const _CmrMinimizedPill({required this.icon, required this.title, required this.onRestore, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAEE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 24, spreadRadius: -14, offset: const Offset(0, 14))],
      ),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF3F5F7), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF0E9F5B), size: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w800, color: Color(0xFF111827)))),
          _RoundWindowButton(icon: Icons.open_in_full_rounded, onTap: onRestore),
          const SizedBox(width: 6),
          _RoundWindowButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _BottomPodium extends StatelessWidget {
  final double bottomLift;
  final Color primary;
  final String buttonText;
  final VoidCallback onPressed;
  final VoidCallback? onAddAnother;

  const _BottomPodium({
    required this.bottomLift,
    required this.primary,
    required this.buttonText,
    required this.onPressed,
    this.onAddAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -bottomLift),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Row(
            children: [
              if (onAddAnother != null) ...[
                Expanded(
                  child: _OutlineSportButton(
                    text: "Добавить ещё",
                    onTap: onAddAnother!,
                    primary: primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _PrimarySportButton(
                  text: buttonText,
                  onTap: onPressed,
                  primary: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
// =====================================================
// Custom Sportoteka Time Picker
// =====================================================
//

Future<TimeOfDay?> showSportotekaTimePicker(
  BuildContext context, {
  required Color primary,
  TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0),
  String title = "Выберите время",
  bool minuteStep5 = true,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<TimeOfDay?>();
  late OverlayEntry entry;

  void close(TimeOfDay? result) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(null),
              child: Container(color: Colors.black.withOpacity(.08)),
            ),
          ),
          Center(
            child: _SportotekaTimePickerWindow(
              primary: primary,
              initial: initial,
              title: title,
              minuteStep5: minuteStep5,
              onClose: close,
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class _SportotekaTimePickerWindow extends StatefulWidget {
  final Color primary;
  final TimeOfDay initial;
  final String title;
  final bool minuteStep5;
  final ValueChanged<TimeOfDay?> onClose;

  const _SportotekaTimePickerWindow({
    required this.primary,
    required this.initial,
    required this.title,
    required this.minuteStep5,
    required this.onClose,
  });

  @override
  State<_SportotekaTimePickerWindow> createState() => _SportotekaTimePickerWindowState();
}

class _SportotekaTimePickerWindowState extends State<_SportotekaTimePickerWindow>
    with SingleTickerProviderStateMixin {
  late int _hour;
  late int _minute;
  late final List<int> _minutes;
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minuteStep5
        ? List<int>.generate(12, (i) => i * 5)
        : List<int>.generate(60, (i) => i);
    _hour = widget.initial.hour.clamp(0, 23).toInt();

    if (widget.minuteStep5) {
      _minute = _minutes.reduce((a, b) {
        return (widget.initial.minute - a).abs() <= (widget.initial.minute - b).abs() ? a : b;
      });
    } else {
      _minute = widget.initial.minute.clamp(0, 59).toInt();
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
    _scale = Tween<double>(begin: .96, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = math.min(360, size.width - 28).toDouble();
    final double maxHeight = math.min(520, size.height - 44).toDouble();

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width,
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.14),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactTimeHeader(
                    primary: widget.primary,
                    title: widget.title,
                    value: '${_two(_hour)}:${_two(_minute)}',
                    onClose: () => widget.onClose(null),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CompactTimeLabel('Часы'),
                          const SizedBox(height: 8),
                          _CompactTimeGrid(
                            values: List<int>.generate(24, (i) => i),
                            selected: _hour,
                            columns: 6,
                            primary: widget.primary,
                            formatter: _two,
                            onChanged: (v) => setState(() => _hour = v),
                          ),
                          const SizedBox(height: 14),
                          const _CompactTimeLabel('Минуты'),
                          const SizedBox(height: 8),
                          _CompactTimeGrid(
                            values: _minutes,
                            selected: _minute,
                            columns: 6,
                            primary: widget.primary,
                            formatter: _two,
                            onChanged: (v) => setState(() => _minute = v),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _CompactTimeAction(
                                  text: 'Отмена',
                                  primary: widget.primary,
                                  filled: false,
                                  onTap: () => widget.onClose(null),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CompactTimeAction(
                                  text: 'Готово',
                                  primary: widget.primary,
                                  filled: true,
                                  onTap: () => widget.onClose(TimeOfDay(hour: _hour, minute: _minute)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactTimeHeader extends StatelessWidget {
  final Color primary;
  final String title;
  final String value;
  final VoidCallback onClose;

  const _CompactTimeHeader({
    required this.primary,
    required this.title,
    required this.value,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _CompactRoundButton(
            icon: Icons.close_rounded,
            onTap: onClose,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Компактный выбор времени',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: primary.withOpacity(.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withOpacity(.22)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CompactRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class _CompactTimeLabel extends StatelessWidget {
  final String text;
  const _CompactTimeLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.2,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _CompactTimeGrid extends StatelessWidget {
  final List<int> values;
  final int selected;
  final int columns;
  final Color primary;
  final String Function(int value) formatter;
  final ValueChanged<int> onChanged;

  const _CompactTimeGrid({
    required this.values,
    required this.selected,
    required this.columns,
    required this.primary,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gap = 6;
        final double itemWidth = ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: values.map((value) {
            final active = value == selected;
            return SizedBox(
              width: itemWidth,
              child: _CompactTimeCell(
                text: formatter(value),
                active: active,
                primary: primary,
                onTap: () => onChanged(value),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CompactTimeCell extends StatelessWidget {
  final String text;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  const _CompactTimeCell({
    required this.text,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          height: 32,
          decoration: BoxDecoration(
            color: active ? primary.withOpacity(.10) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? primary.withOpacity(.35) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.4,
                fontWeight: FontWeight.w900,
                color: active ? primary : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactTimeAction extends StatelessWidget {
  final String text;
  final Color primary;
  final bool filled;
  final VoidCallback onTap;

  const _CompactTimeAction({
    required this.text,
    required this.primary,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 36,
          decoration: BoxDecoration(
            color: filled ? primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: filled ? primary : primary.withOpacity(.26)),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
                color: filled ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimarySportButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color primary;

  const _PrimarySportButton({
    required this.text,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.85)],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineSportButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color primary;

  const _OutlineSportButton({
    required this.text,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.35)),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}