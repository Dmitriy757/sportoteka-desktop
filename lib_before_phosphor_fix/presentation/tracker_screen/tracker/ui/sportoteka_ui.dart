import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

abstract final class STColors {
  static const canvas = Colors.white;
  static const surface = Colors.white;
  static const soft = Color(0xFFF7F8F7);
  static const soft2 = Color(0xFFF2F4F2);
  static const text = Color(0xFF0B0F14);
  static const textSecondary = Color(0xFF374151);
  static const textMuted = Color(0xFF6B7280);
  static const divider = Color(0xFFE9ECEA);
  static const dividerStrong = Color(0xFFDDE2DF);
  static const graphite = Color(0xFF111827);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF1F1);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFFF7E8);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFF4F7FF);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF7C3AED);
}

abstract final class STSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const EdgeInsets pageMobile = EdgeInsets.symmetric(horizontal: 4);
  static const EdgeInsets pageTablet = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets section = EdgeInsets.fromLTRB(12, 12, 12, 12);
  static const EdgeInsets sectionCompact = EdgeInsets.fromLTRB(8, 8, 8, 8);
}

abstract final class STRadius {
  static const double none = 0;
  static const double control = 8;
  static const double button = 12;
  static const double modal = 16;
  static const double pill = 999;
}

abstract final class STMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;
}

abstract final class STText {
  static const String family = 'Inter';
  static const List<String> fallback = <String>['SF Pro Text', 'SF Pro Display', 'Roboto', 'Segoe UI', 'Arial'];

  static TextStyle title(double size) => TextStyle(
        color: STColors.text,
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle value(double size) => TextStyle(
        color: STColors.text,
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.16,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(double size) => TextStyle(
        color: STColors.textSecondary,
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.32,
      );

  static TextStyle muted(double size) => TextStyle(
        color: STColors.textMuted,
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.30,
      );

  static TextStyle label(double size) => TextStyle(
        color: STColors.textMuted,
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.16,
      );
}

abstract final class STDecor {
  static const BoxDecoration canvas = BoxDecoration(color: STColors.canvas);

  static BoxDecoration section({bool top = false, bool bottom = true}) => BoxDecoration(
        color: STColors.surface,
        border: Border(
          top: top ? const BorderSide(color: STColors.divider, width: .65) : BorderSide.none,
          bottom: bottom ? const BorderSide(color: STColors.divider, width: .65) : BorderSide.none,
        ),
      );

  static BoxDecoration selectedSection() => const BoxDecoration(
        color: STColors.greenSoft,
        border: Border(left: BorderSide(color: STColors.green, width: 3)),
      );

  static BoxDecoration control({bool active = false, Color? accent}) {
    final color = accent ?? STColors.green;
    return BoxDecoration(
      color: active ? color.withOpacity(.07) : STColors.soft,
      borderRadius: BorderRadius.circular(STRadius.control),
      border: active ? Border.all(color: color.withOpacity(.18), width: .7) : null,
    );
  }

  static BoxDecoration modal() => BoxDecoration(
        color: STColors.surface,
        borderRadius: BorderRadius.circular(STRadius.modal),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 28, spreadRadius: -14, offset: const Offset(0, 16))],
      );
}

class STSection extends StatelessWidget {
  const STSection({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = STSpace.section,
    this.showTopDivider = false,
    this.showBottomDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showTopDivider;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: STDecor.section(top: showTopDivider, bottom: showBottomDivider),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(children: [
              if (title != null)
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title!, style: STText.title(14)),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: STText.muted(10.5)),
                    ],
                  ]),
                )
              else
                const Spacer(),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: STSpace.md),
          ],
          child,
        ],
      ),
    );
  }
}

class STMetric extends StatelessWidget {
  const STMetric({super.key, required this.value, required this.label, this.note, this.alignment = CrossAxisAlignment.start, this.valueSize = 24});
  final String value;
  final String label;
  final String? note;
  final CrossAxisAlignment alignment;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: STText.value(valueSize)),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: STText.label(9.5)),
          if (note != null && note!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: STText.muted(9)),
          ],
        ],
      );
}

class STStatus extends StatelessWidget {
  const STStatus({super.key, required this.label, required this.color, this.enabled = true});
  final String label;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final resolved = enabled ? color : STColors.textMuted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: resolved, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: STText.label(9.4).copyWith(color: resolved)),
    ]);
  }
}

class STTabs extends StatelessWidget {
  const STTabs({super.key, required this.labels, required this.index, required this.onChanged, this.scrollable = false});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(labels.length, (i) {
      final active = i == index;
      final item = InkWell(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: STMotion.fast,
          curve: STMotion.curve,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? STColors.green : Colors.transparent, width: 2.2))),
          child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: STText.label(10.7).copyWith(color: active ? STColors.text : STColors.textMuted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
      return scrollable ? item : Expanded(child: item);
    });

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: STColors.divider, width: .65))),
      child: scrollable ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: children)) : Row(children: children),
    );
  }
}

class STSearch extends StatelessWidget {
  const STSearch({super.key, required this.controller, this.hint = 'Поиск', this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: STColors.divider, width: .7))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: STText.body(12.5),
              decoration: InputDecoration(hintText: hint, hintStyle: STText.muted(12), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(onTap: controller.clear, child: const Padding(padding: EdgeInsets.all(6), child: Text('×', style: TextStyle(color: STColors.textMuted, fontSize: 18, height: 1)))),
        ]),
      );
}

class STActionButton extends StatelessWidget {
  const STActionButton({super.key, required this.label, required this.onTap, this.primary = false, this.danger = false, this.compact = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = danger ? STColors.red : (primary ? Colors.white : STColors.text);
    final background = danger ? Colors.transparent : (primary ? STColors.green : Colors.white);
    final border = danger ? STColors.red.withOpacity(.35) : (primary ? STColors.green : STColors.divider);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(STRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(STRadius.button),
        child: Opacity(
          opacity: onTap == null ? .5 : 1,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 34 : 38),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 7 : 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(STRadius.button), border: Border.all(color: border, width: .7)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: STText.label(compact ? 10 : 10.8).copyWith(color: foreground)),
          ),
        ),
      ),
    );
  }
}

class STEmptyState extends StatelessWidget {
  const STEmptyState({super.key, required this.title, required this.message, this.actionLabel, this.onAction});
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: STText.title(15)),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center, style: STText.muted(11.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            STActionButton(label: actionLabel!, onTap: onAction, primary: true, compact: true),
          ],
        ]),
      );
}
