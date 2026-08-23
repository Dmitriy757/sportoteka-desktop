import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class PpColors {
  static const bg = Colors.white;
  static const panel = Colors.white;
  static const soft = Color(0xFFF7F8F7);
  static const soft2 = Color(0xFFF2F4F2);
  static const line = Color(0xFFE9ECEA);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF5F6670);
  static const muted2 = Color(0xFF8A9099);

  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenSoft2 = Color(0xFFF8FEFA);
  static const greenBorder = Color(0xFFD7F0E2);

  // Translucent Sportoteka accents used for the dot/glass language.
  static const greenGlass = Color(0xFFF9FDFB);
  static const amberGlass = Color(0xFFFFFCF5);
  static const redGlass = Color(0xFFFFFAF9);

  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF1F1);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFFF7E8);
}

class PpText {
  // One visual scale for the entire player profile.
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

  static double _valueSize(double requested) {
    if (requested >= 16.5) return 17;
    if (requested >= 14.5) return 15;
    return 14;
  }

  static double _captionSize(double requested) {
    return requested < 10 ? 9.5 : 10.2;
  }

  static TextStyle title(double size) => AppTypography.custom(
        size: _titleSize(size),
        weight: FontWeight.w600,
        color: PpColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle body(
    double size, {
    Color color = PpColors.muted,
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
        size: _valueSize(size),
        weight: FontWeight.w600,
        color: PpColors.text,
        height: 1.12,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle caption({
    double size = 10.2,
    Color color = PpColors.muted2,
  }) =>
      AppTypography.custom(
        size: _captionSize(size),
        weight: FontWeight.w500,
        color: color,
        height: 1.18,
        letterSpacing: 0,
      );
}

class PpSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final bool bordered;
  final bool elevated;

  const PpSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = PpColors.panel,
    this.radius = 12,
    this.bordered = false,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: bordered
            ? Border.all(
                color: color == PpColors.greenSoft ||
                        color == PpColors.greenSoft2
                    ? PpColors.greenBorder
                    : PpColors.line.withOpacity(.72),
                width: .65,
              )
            : null,
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(.018),
                  blurRadius: 18,
                  spreadRadius: -14,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class PpDot extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final bool glow;

  const PpDot({
    super.key,
    this.size = 6,
    this.color = PpColors.green,
    this.opacity = 1,
    this.glow = true,
  });

  const PpDot.green({
    super.key,
    this.size = 6,
    this.opacity = 1,
    this.glow = true,
  }) : color = PpColors.green;

  const PpDot.amber({
    super.key,
    this.size = 6,
    this.opacity = 1,
    this.glow = true,
  }) : color = PpColors.amber;

  const PpDot.red({
    super.key,
    this.size = 6,
    this.opacity = 1,
    this.glow = true,
  }) : color = PpColors.red;

  const PpDot.muted({
    super.key,
    this.size = 6,
    this.opacity = 1,
    this.glow = false,
  }) : color = PpColors.muted2;

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
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .25,
                  ),
                  BoxShadow(
                    color: color.withOpacity(.08),
                    blurRadius: size * 3.2,
                    spreadRadius: .6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class PpDotCluster extends StatelessWidget {
  final Color color;
  final bool glow;

  const PpDotCluster({
    super.key,
    this.color = PpColors.green,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PpDot(
          size: 3.5,
          color: color,
          opacity: .22,
          glow: false,
        ),
        const SizedBox(width: 3),
        PpDot(
          size: 4.5,
          color: color,
          opacity: .42,
          glow: false,
        ),
        const SizedBox(width: 3),
        PpDot(
          size: 5.5,
          color: color,
          opacity: .68,
          glow: false,
        ),
        const SizedBox(width: 3),
        PpDot(
          size: 6.5,
          color: color,
          glow: glow,
        ),
      ],
    );
  }
}

class PpThinDivider extends StatelessWidget {
  final EdgeInsets margin;
  final double thickness;
  final double opacity;

  const PpThinDivider({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.thickness = .65,
    this.opacity = .92,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: thickness,
      color: PpColors.line.withOpacity(opacity),
    );
  }
}

class PpSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color dotColor;

  const PpSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.dotColor = PpColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: PpDot(color: dotColor, size: 7),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PpText.title(14)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: PpText.body(10.2)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class PpMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Color dotColor;
  final double dotSize;

  const PpMetric({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.dotColor = PpColors.green,
    this.dotSize = 5,
  });

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      color: Color.alphaBlend(
        dotColor.withOpacity(.032),
        PpColors.soft,
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PpText.caption(),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PpText.value(17),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.body(9.5),
            ),
          ],
        ],
      ),
    );
  }
}

class PpTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color dotColor;
  final bool emphasized;

  const PpTextAction({
    super.key,
    required this.label,
    this.onTap,
    this.dotColor = PpColors.green,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? Color.alphaBlend(
              dotColor.withOpacity(.08),
              Colors.white,
            )
          : Color.alphaBlend(
              dotColor.withOpacity(.025),
              PpColors.soft,
            ),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PpDot(color: dotColor, size: 5),
              const SizedBox(width: 6),
              Text(
                label,
                style: PpText.body(
                  10.2,
                  color: emphasized ? PpColors.greenDark : PpColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PpActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const PpActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final accent = danger ? PpColors.red : PpColors.green;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: active ? 1 : .48,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: danger
                  ? Color.alphaBlend(
                      PpColors.red.withOpacity(.055),
                      Colors.white,
                    )
                  : Color.alphaBlend(
                      PpColors.green.withOpacity(.022),
                      PpColors.soft,
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.78),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PpText.body(
                          11,
                          color: danger ? PpColors.red : PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: PpText.body(10.2)),
                    ],
                  ),
                ),
                if (active)
                  Text(
                    'Открыть',
                    style: PpText.caption(
                      size: 9.5,
                      color: danger ? PpColors.red : PpColors.greenDark,
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

class PpDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Color dotColor;
  final double maxWidth;

  const PpDialogShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.actions,
    this.dotColor = PpColors.green,
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
            boxShadow: const [
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
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: PpDot(color: dotColor, size: 7),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: PpText.title(16)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: PpText.body(10.2)),
                        ],
                      ],
                    ),
                  ),
                  PpDotCluster(color: dotColor),
                ],
              ),
              const PpThinDivider(
                margin: EdgeInsets.symmetric(vertical: 12),
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

class PpDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  const PpDialogButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? PpColors.red : PpColors.greenDark;
    final background = primary
        ? (danger ? PpColors.redSoft : PpColors.greenSoft)
        : PpColors.soft;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (primary) ...[
                  PpDot(color: accent, size: 5.5),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: PpText.body(
                    10.6,
                    color: primary ? accent : PpColors.text,
                    weight: FontWeight.w600,
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

class PpEmpty extends StatelessWidget {
  final String title;
  final String text;
  final IconData? icon;

  const PpEmpty({
    super.key,
    required this.title,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PpDotCluster(),
              const SizedBox(height: 12),
              Text(
                title,
                style: PpText.title(14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                text,
                textAlign: TextAlign.center,
                style: PpText.body(10.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
