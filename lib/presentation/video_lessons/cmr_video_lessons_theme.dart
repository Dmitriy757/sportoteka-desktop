import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

/// Shared visual language for the Video Lessons module.
/// Mirrors the flagship player profile: white canvas, soft surfaces,
/// restrained green accents, compact typography and dot-based hierarchy.
class CmrVideoColors {
  static const bg = Colors.white;
  static const panel = Colors.white;
  static const soft = Color(0xFFF7F8F7);
  static const soft2 = Color(0xFFF2F4F2);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF5F6670);
  static const subtle = Color(0xFF8A9099);
  static const line = Color(0xFFE9ECEA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenSoft2 = Color(0xFFF8FEFA);
  static const greenBorder = Color(0xFFD7F0E2);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF1F1);
  static const amber = Color(0xFFF59E0B);
}

class CmrVideoText {
  static double _titleSize(double requested) {
    if (requested >= 17) return 18;
    if (requested >= 15) return 16;
    return 14;
  }

  static double _bodySize(double requested) {
    if (requested < 9.4) return 9.5;
    if (requested < 10.6) return 10.2;
    if (requested < 11.7) return 11;
    if (requested < 12.7) return 12;
    return 13;
  }

  static double _captionSize(double requested) => requested < 10 ? 9.5 : 10.2;

  static TextStyle title(double size) => AppTypography.custom(
        size: _titleSize(size),
        weight: FontWeight.w600,
        color: CmrVideoColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle body(
    double size, {
    Color color = CmrVideoColors.muted,
    FontWeight weight = FontWeight.w400,
  }) =>
      AppTypography.custom(
        size: _bodySize(size),
        weight: weight,
        color: color,
        height: 1.30,
        letterSpacing: 0,
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size >= 16.5 ? 17 : (size >= 14.5 ? 15 : 14),
        weight: FontWeight.w600,
        color: CmrVideoColors.text,
        height: 1.12,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle action([Color color = CmrVideoColors.text]) =>
      AppTypography.custom(
        size: 10.2,
        weight: FontWeight.w600,
        color: color,
        height: 1.2,
        letterSpacing: 0,
      );

  static TextStyle caption({
    double size = 10.2,
    Color color = CmrVideoColors.subtle,
  }) =>
      AppTypography.custom(
        size: _captionSize(size),
        weight: FontWeight.w500,
        color: color,
        height: 1.18,
        letterSpacing: 0,
      );
}

class CmrVideoDecor {
  static List<BoxShadow> get windowShadow => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(.018),
          blurRadius: 18,
          spreadRadius: -14,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration window({double radius = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: windowShadow,
      );

  static BoxDecoration soft({bool active = false, double radius = 10}) =>
      BoxDecoration(
        color: active ? CmrVideoColors.greenSoft : CmrVideoColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}

class CmrVideoSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final bool elevated;

  const CmrVideoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = CmrVideoColors.panel,
    this.radius = 12,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? CmrVideoDecor.windowShadow : null,
      ),
      child: child,
    );
  }
}

class CmrVideoDot extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const CmrVideoDot({
    super.key,
    this.size = 6,
    this.color = CmrVideoColors.green,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withOpacity(.16),
              blurRadius: size * 1.8,
              spreadRadius: .2,
            ),
          ],
        ),
      ),
    );
  }
}

class CmrVideoDotCluster extends StatelessWidget {
  final Color color;

  const CmrVideoDotCluster({
    super.key,
    this.color = CmrVideoColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CmrVideoDot(size: 3.5, color: color, opacity: .22),
        const SizedBox(width: 3),
        CmrVideoDot(size: 4.5, color: color, opacity: .42),
        const SizedBox(width: 3),
        CmrVideoDot(size: 5.5, color: color, opacity: .68),
        const SizedBox(width: 3),
        CmrVideoDot(size: 6.5, color: color),
      ],
    );
  }
}

class CmrVideoSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color dotColor;

  const CmrVideoSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.dotColor = CmrVideoColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: CmrVideoDot(color: dotColor, size: 7),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: CmrVideoText.title(14)),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(subtitle!, style: CmrVideoText.body(10.2)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class CmrVideoIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;

  const CmrVideoIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? CmrVideoColors.red
        : accent
            ? CmrVideoColors.greenDark
            : CmrVideoColors.text;
    final background = danger
        ? CmrVideoColors.redSoft
        : accent
            ? CmrVideoColors.greenSoft
            : CmrVideoColors.soft;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class CmrVideoTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final Widget? leading;

  const CmrVideoTextButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.danger = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? CmrVideoColors.redSoft
        : primary
            ? CmrVideoColors.green
            : CmrVideoColors.soft;
    final foreground = danger
        ? CmrVideoColors.red
        : primary
            ? Colors.white
            : CmrVideoColors.text;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                IconTheme(
                  data: IconThemeData(color: foreground, size: 15),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(label, style: CmrVideoText.action(foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration cmrVideoInputDecoration(
  String label, {
  String? hint,
  EdgeInsets contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: CmrVideoText.body(10.6, color: CmrVideoColors.subtle),
    floatingLabelStyle: CmrVideoText.caption(
      size: 9.5,
      color: CmrVideoColors.greenDark,
    ),
    hintStyle: CmrVideoText.body(10.6, color: CmrVideoColors.subtle),
    filled: true,
    fillColor: CmrVideoColors.soft,
    contentPadding: contentPadding,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

class CmrVideoDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Color dotColor;
  final double maxWidth;

  const CmrVideoDialogShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.actions,
    this.dotColor = CmrVideoColors.green,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1A0B0F14),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CmrVideoDot(color: dotColor, size: 7),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: CmrVideoText.title(16)),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: CmrVideoText.body(10.2)),
                        ],
                      ],
                    ),
                  ),
                  CmrVideoDotCluster(color: dotColor),
                ],
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: .65,
                color: CmrVideoColors.line,
              ),
              child,
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .asMap()
                    .entries
                    .expand(
                      (entry) => <Widget>[
                        if (entry.key > 0) const SizedBox(width: 7),
                        entry.value,
                      ],
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Forces the module to inherit the same font family as AppTypography even in
/// older widgets that still provide local TextStyle overrides.
class CmrVideoThemeScope extends StatelessWidget {
  final Widget child;

  const CmrVideoThemeScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final sample = CmrVideoText.body(11);
    final family = sample.fontFamily;
    final fallback = sample.fontFamilyFallback;

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: CmrVideoColors.bg,
        canvasColor: CmrVideoColors.bg,
        textTheme: base.textTheme.apply(
          fontFamily: family,
          fontFamilyFallback: fallback,
          bodyColor: CmrVideoColors.text,
          displayColor: CmrVideoColors.text,
        ),
      ),
      child: child,
    );
  }
}
