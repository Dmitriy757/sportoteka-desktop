import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'team_calendar_models.dart';

class EventEditorSheet extends StatefulWidget {
  final Color primary;
  final int teamId;
  final int clubId;
  final int createdBy;
  final DateTime initialDateTime;
  final TeamEvent? initial;
  final Function(TeamEvent)? onEventAdded;
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

    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: start,
      locale: const Locale('ru', 'RU'),
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

    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: base,
      locale: const Locale('ru', 'RU'),
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

  void _submitAndClose() async {
    if (await _validate()) {
      final ev = _createEvent();
      Navigator.pop<TeamEvent>(context, ev);
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    if (widget.embedded) {
      return Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 96 + viewInsets),
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
                  buttonText: widget.initial == null ? "Добавить" : "Сохранить",
                  onPressed: widget.initial == null
                      ? _submitAndClose
                      : () async {
                          if (await _validate()) {
                            Navigator.pop<TeamEvent>(context, _createEvent());
                          }
                        },
                  onAddAnother:
                      widget.initial == null && widget.onEventAdded != null
                          ? _submitAndAddAnother
                          : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.76,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        _sheetScrollCtrl = scrollController;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + 92 + viewInsets),
                  child: _buildAdaptiveFormContent(
                    scrollController: scrollController,
                    viewInsets: viewInsets,
                    showSheetHeader: true,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomPodium(
                    bottomLift: viewInsets,
                    primary: widget.primary,
                    buttonText: widget.initial == null ? "Добавить" : "Сохранить",
                    onPressed: widget.initial == null
                        ? _submitAndClose
                        : () async {
                            if (await _validate()) {
                              Navigator.pop<TeamEvent>(context, _createEvent());
                            }
                          },
                    onAddAnother:
                        widget.initial == null && widget.onEventAdded != null
                            ? _submitAndAddAnother
                            : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            const SizedBox(height: 12),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Закрыть"),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _titleKey,
                          child: _card(
                            child: TextField(
                              focusNode: _titleF,
                              controller: titleC,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_locationF),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: "Название события",
                                hintText: "Например: U16 / УТЗ / Матч",
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _locationKey,
                          child: _card(
                            child: TextField(
                              focusNode: _locationF,
                              controller: locationC,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_notesF),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: "Место",
                                hintText: "Стадион / зал / поле",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        _timeBlock(),
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: _notesKey,
                          child: _card(
                            child: TextField(
                              focusNode: _notesF,
                              controller: notesC,
                              minLines: 4,
                              maxLines: 6,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: "Примечание",
                                hintText: "Задачи, инвентарь, важные детали",
                              ),
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
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _titleKey,
              child: _card(
                child: TextField(
                  focusNode: _titleF,
                  controller: titleC,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_locationF),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: "Название события",
                    hintText: "Например: U16 / УТЗ / Матч",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _timeBlock(),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _locationKey,
              child: _card(
                child: TextField(
                  focusNode: _locationF,
                  controller: locationC,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesF),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: "Место",
                    hintText: "Стадион / зал / поле",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _notesKey,
              child: _card(
                child: TextField(
                  focusNode: _notesF,
                  controller: notesC,
                  minLines: 2,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: "Примечание",
                    hintText: "Необязательно",
                  ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
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
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
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
              const SizedBox(width: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
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
                const SizedBox(width: 10),
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
  return showModalBottomSheet<TimeOfDay?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _SportotekaTimePickerSheet(
      primary: primary,
      initial: initial,
      title: title,
      minuteStep5: minuteStep5,
    ),
  );
}

class _SportotekaTimePickerSheet extends StatefulWidget {
  final Color primary;
  final TimeOfDay initial;
  final String title;
  final bool minuteStep5;

  const _SportotekaTimePickerSheet({
    required this.primary,
    required this.initial,
    required this.title,
    required this.minuteStep5,
  });

  @override
  State<_SportotekaTimePickerSheet> createState() =>
      _SportotekaTimePickerSheetState();
}

class _SportotekaTimePickerSheetState extends State<_SportotekaTimePickerSheet>
    with SingleTickerProviderStateMixin {
  static const double _radius = 22;
  static const double _itemExtent = 44;

  late final FixedExtentScrollController _hoursCtrl;
  late final FixedExtentScrollController _minutesCtrl;

  late int _hour;
  late int _minute;
  late final List<int> _minutesList;

  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _minutesList = widget.minuteStep5
        ? List<int>.generate(12, (i) => i * 5)
        : List<int>.generate(60, (i) => i);

    _hour = widget.initial.hour.clamp(0, 23);

    if (widget.minuteStep5) {
      int nearest = _minutesList.first;
      int best = 999;
      for (final m in _minutesList) {
        final d = (widget.initial.minute - m).abs();
        if (d < best) {
          best = d;
          nearest = m;
        }
      }
      _minute = nearest;
    } else {
      _minute = widget.initial.minute.clamp(0, 59);
    }

    _hoursCtrl = FixedExtentScrollController(initialItem: _hour);
    _minutesCtrl = FixedExtentScrollController(
      initialItem: math.max(0, _minutesList.indexOf(_minute)),
    );

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  void _onDone() {
    Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));
  }

  void _onCancel() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final lift = (1 - _anim.value) * 16;
        final fade = _anim.value;

        return Transform.translate(
          offset: Offset(0, lift),
          child: Opacity(opacity: fade, child: child),
        );
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: math.max(0, bottomInset)),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      _TimeChip(
                        primary: widget.primary,
                        text: "${_two(_hour)}:${_two(_minute)}",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: _PickerFrame(
                    primary: widget.primary,
                    child: SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            child: _CupertinoWheel(
                              controller: _hoursCtrl,
                              itemExtent: _itemExtent,
                              count: 24,
                              labelBuilder: (i) => _two(i),
                              onSelected: (i) => setState(() => _hour = i),
                            ),
                          ),
                          _Colon(primary: widget.primary),
                          Expanded(
                            child: _CupertinoWheel(
                              controller: _minutesCtrl,
                              itemExtent: _itemExtent,
                              count: _minutesList.length,
                              labelBuilder: (i) => _two(_minutesList[i]),
                              onSelected: (i) =>
                                  setState(() => _minute = _minutesList[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OutlineSportButton(
                          text: "Отмена",
                          onTap: _onCancel,
                          primary: widget.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimarySportButton(
                          text: "Готово",
                          onTap: _onDone,
                          primary: widget.primary,
                        ),
                      ),
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

class _PickerFrame extends StatelessWidget {
  final Widget child;
  final Color primary;

  const _PickerFrame({required this.child, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          IgnorePointer(
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary.withOpacity(0.22)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final double itemExtent;
  final int count;
  final String Function(int i) labelBuilder;
  final ValueChanged<int> onSelected;

  const _CupertinoWheel({
    required this.controller,
    required this.itemExtent,
    required this.count,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: itemExtent,
      diameterRatio: 1.18,
      squeeze: 1.08,
      magnification: 1.08,
      useMagnifier: true,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelected,
      children: List.generate(count, (i) {
        return Center(
          child: Text(
            labelBuilder(i),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: 0.2,
            ),
          ),
        );
      }),
    );
  }
}

class _Colon extends StatelessWidget {
  final Color primary;
  const _Colon({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      child: Text(
        ":",
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: primary.withOpacity(0.85),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final Color primary;
  final String text;
  const _TimeChip({required this.primary, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: primary,
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