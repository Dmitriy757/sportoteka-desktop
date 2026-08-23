import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class GzColors {
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);
  static const Color divider = Color(0xFFE9ECEA);
  static const Color line = Color(0xFFE9ECEA);

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF5F6670);
  static const Color subtle = Color(0xFF8A9099);
  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF4B5563);

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
}

class GzText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: GzColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: GzColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle section() => AppTypography.custom(
        size: 12.2,
        weight: FontWeight.w600,
        color: GzColors.text,
        height: 1.20,
        letterSpacing: 0,
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: GzColors.muted2,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle caption() => AppTypography.custom(
        size: 10.8,
        weight: FontWeight.w500,
        color: GzColors.subtle,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle action({Color color = GzColors.text}) =>
      AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
      );
}

class GameZoneCmr {
  // Оставлено для обратной совместимости с уже существующими TextStyle.
  // Основной шрифт раздела задаётся через AppTypography ниже.
  static const List<String> fontFallback = <String>[
    'Inter',
    'SF Pro Text',
    'SF Pro Display',
    'Roboto',
    'Arial',
  ];

  static bool mobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 720;

  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.015),
          blurRadius: 16,
          spreadRadius: -11,
          offset: const Offset(0, 9),
        ),
      ];

  static ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: GzColors.bg,
      dividerColor: GzColors.divider,
      splashColor: GzColors.green.withOpacity(.035),
      highlightColor: GzColors.green.withOpacity(.025),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: GzColors.green),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: GzColors.greenDark,
        selectionColor: GzColors.green.withOpacity(.14),
        selectionHandleColor: GzColors.green,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GzColors.soft,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: GzColors.red.withOpacity(.22),
            width: .8,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: GzColors.red.withOpacity(.32),
            width: .8,
          ),
        ),
        labelStyle: GzText.muted(11.3),
        floatingLabelStyle: GzText.caption().copyWith(
          color: GzColors.greenDark,
        ),
        hintStyle: GzText.muted(11.5).copyWith(color: GzColors.subtle),
        prefixIconColor: GzColors.muted2,
        suffixIconColor: GzColors.muted2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButton(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: secondaryButton(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GzColors.graphiteSoft,
          textStyle: GzText.action(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: GzColors.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedTextStyle: GzText.action(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GzColors.graphite,
        contentTextStyle: GzText.muted(11.5).copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: GzColors.text,
        displayColor: GzColors.text,
      ),
    );
  }

  static PreferredSizeWidget appBar({
    Widget? title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    Color? backgroundColor,
    double? elevation,
    Color? surfaceTintColor,
    bool? centerTitle,
    TextStyle? titleTextStyle,
    IconThemeData? iconTheme,
    IconThemeData? actionsIconTheme,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: GzColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      iconTheme:
          iconTheme ?? const IconThemeData(color: GzColors.text, size: 18),
      actionsIconTheme:
          actionsIconTheme ?? const IconThemeData(color: GzColors.text, size: 18),
      titleSpacing: 2,
      toolbarHeight: 54,
      title: DefaultTextStyle.merge(
        style: titleTextStyle ?? GzText.title(16.5),
        child: title ?? const SizedBox.shrink(),
      ),
      actions: actions,
    );
  }

  static Widget surface(BuildContext context, {required Widget child}) {
    return Theme(
      data: _theme(context),
      child: DefaultTextStyle.merge(
        style: GzText.muted(12).copyWith(color: GzColors.text),
        child: child,
      ),
    );
  }

  static Widget page(BuildContext context, {required Widget child}) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 980;
    final mobileView = width < 640;
    return Theme(
      data: _theme(context),
      child: DefaultTextStyle.merge(
        style: GzText.muted(12).copyWith(color: GzColors.text),
        child: Container(
          width: double.infinity,
          color: const Color(0xFFF6F7F6),
          padding: EdgeInsets.all(mobileView ? 6 : (compact ? 8 : 10)),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(mobileView ? 18 : (compact ? 18 : 20)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(mobileView ? 18 : (compact ? 18 : 20)),
                boxShadow: windowShadow,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  static EdgeInsets listPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.fromLTRB(
      width < 640 ? 10 : 14,
      width < 640 ? 10 : 14,
      width < 640 ? 10 : 14,
      width < 640 ? 22 : 24,
    );
  }

  static BoxDecoration card({
    Color color = Colors.white,
    Color? borderColor,
    double radius = 12,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor, width: .7),
      boxShadow: elevated ? cardShadow : null,
    );
  }

  static Widget header({
    required String title,
    required String subtitle,
    IconData icon = Icons.sports_esports_rounded,
    List<Widget> stats = const [],
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: card(color: GzColors.panel, radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: _GzGlowDot(color: GzColors.green, size: 6.4),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GzText.title(16.5)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: GzText.muted(10.8)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _GzDotCluster(),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: stats),
          ],
        ],
      ),
    );
  }

  static Widget stat(
    String title,
    String value, {
    Color color = GzColors.green,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: card(color: GzColors.soft, radius: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GzText.value(15.5).copyWith(color: color),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GzText.caption(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget chip({
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 34),
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 10 : 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: selected ? GzColors.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? GzColors.greenBorder : Colors.transparent,
          width: .8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            _GzGlowDot(
              color: selected ? GzColors.green : GzColors.muted2,
              size: selected ? 6 : 4.8,
              opacity: selected ? 1 : .48,
              halo: selected,
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: GzText.action(
              color: selected ? GzColors.greenDark : GzColors.muted2,
            ).copyWith(
              fontSize: 11.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: content,
      ),
    );
  }

  static Widget sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GzText.section()),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: GzText.muted(10.6)),
          ],
        ],
      ),
    );
  }

  static Widget empty({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: card(color: GzColors.soft, radius: 12),
      child: Column(
        children: [
          const _GzDotCluster(),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center, style: GzText.title(14.2)),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GzText.muted(11.2),
          ),
          if (action != null) ...[
            const SizedBox(height: 13),
            action,
          ],
        ],
      ),
    );
  }

  static Widget sheet({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 10, 16, 18),
  }) {
    return SafeArea(
      top: false,
      child: Container(
        padding: padding,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: child,
      ),
    );
  }

  static Widget sheetGrabber() => Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: GzColors.divider,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  static ButtonStyle primaryButton() => ElevatedButton.styleFrom(
        backgroundColor: GzColors.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GzText.action(color: Colors.white),
      );

  static ButtonStyle greenButton() => ElevatedButton.styleFrom(
        backgroundColor: GzColors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GzText.action(color: Colors.white),
      );

  static ButtonStyle secondaryButton() => OutlinedButton.styleFrom(
        foregroundColor: GzColors.text,
        side: BorderSide.none,
        backgroundColor: GzColors.soft,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GzText.action(),
      );
}

class _GzGlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final bool halo;

  const _GzGlowDot({
    required this.color,
    this.size = 6,
    this.opacity = 1,
    this.halo = true,
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
          boxShadow: halo
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .2,
                  ),
                  BoxShadow(
                    color: color.withOpacity(.07),
                    blurRadius: size * 3,
                    spreadRadius: .5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _GzDotCluster extends StatelessWidget {
  const _GzDotCluster();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GzGlowDot(
          color: GzColors.green,
          size: 3.5,
          opacity: .25,
          halo: false,
        ),
        SizedBox(width: 3),
        _GzGlowDot(
          color: GzColors.green,
          size: 4.5,
          opacity: .48,
          halo: false,
        ),
        SizedBox(width: 3),
        _GzGlowDot(
          color: GzColors.green,
          size: 5.5,
          opacity: .72,
          halo: false,
        ),
        SizedBox(width: 3),
        _GzGlowDot(color: GzColors.green, size: 6.5),
      ],
    );
  }
}
