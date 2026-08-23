import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ===============================
/// SportotekaTimePicker (24h, RU)
/// ===============================
/// Использование:
/// final t = await showSportotekaTimePicker(context,
///   initial: const TimeOfDay(hour: 19, minute: 30),
///   title: "Выберите время",
/// );
/// if (t != null) { ... }
Future<TimeOfDay?> showSportotekaTimePicker(
  BuildContext context, {
  TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0),
  String title = "Выберите время",
  bool minuteStep5 = true, // ✅ удобно: 00/05/10...
}) async {
  return showModalBottomSheet<TimeOfDay?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _SportotekaTimePickerSheet(
      initial: initial,
      title: title,
      minuteStep5: minuteStep5,
    ),
  );
}

/// Внутренний шит
class _SportotekaTimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  final String title;
  final bool minuteStep5;

  const _SportotekaTimePickerSheet({
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

  // animation for small “lift” effect
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _minutesList = widget.minuteStep5
        ? List<int>.generate(12, (i) => i * 5) // 0..55 step 5
        : List<int>.generate(60, (i) => i);

    _hour = widget.initial.hour.clamp(0, 23);

    // минуту приводим к шагу, если step5
    if (widget.minuteStep5) {
      final nearest = (_minutesList..sort((a, b) => a.compareTo(b)))
          .reduce((a, b) => (widget.initial.minute - a).abs() <
                  (widget.initial.minute - b).abs()
              ? a
              : b);
      _minute = nearest;
    } else {
      _minute = widget.initial.minute.clamp(0, 59);
    }

    _hoursCtrl = FixedExtentScrollController(initialItem: _hour);
    _minutesCtrl = FixedExtentScrollController(
      initialItem: _minutesList.indexOf(_minute).clamp(0, _minutesList.length),
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

  Color get _primary {
    // Если у тебя есть фирменный цвет, можешь заменить на константу
    // например: const Color(0xFF0B5ED7)
    final cs = Theme.of(context).colorScheme;
    return cs.primary;
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
        final lift = (1 - _anim.value) * 16; // slide-up
        final fade = _anim.value;

        return Transform.translate(
          offset: Offset(0, lift),
          child: Opacity(
            opacity: fade,
            child: child,
          ),
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
                // ====== handle ======
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

                // ====== header ======
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
                        primary: _primary,
                        text: "${_two(_hour)}:${_two(_minute)}",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ====== pickers ======
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: _PickerFrame(
                    primary: _primary,
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
                          _Colon(primary: _primary),
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

                // ====== helper text ======
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: _primary.withOpacity(0.85)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.minuteStep5
                              ? "Шаг минут: 5 (можно отключить)."
                              : "Точный выбор минут (0–59).",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ====== buttons ======
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OutlineSportButton(
                          text: "Отмена",
                          onTap: _onCancel,
                          primary: _primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimarySportButton(
                          text: "Готово",
                          onTap: _onDone,
                          primary: _primary,
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

/// Рамка с подсветкой выбора (центр wheel)
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
      selectionOverlay: const SizedBox.shrink(), // мы рисуем свой overlay
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

/// Синяя кнопка (Sportoteka стиль)
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
              colors: [
                primary,
                primary.withOpacity(0.85),
              ],
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

/// Контурная кнопка
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
              style: TextStyle(
                color: const Color(0xFF111827),
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
