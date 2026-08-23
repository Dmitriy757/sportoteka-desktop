import 'package:flutter/material.dart';

class GzColors {
  static const Color bg = Color(0xFFFFFFFF);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFFAFBFC);
  static const Color soft2 = Color(0xFFF6F7F9);
  static const Color divider = Color(0xFFF0F2F4);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color subtle = Color(0xFF6B7280);
  static const Color graphite = Color(0xFF111827);
  static const Color green = Color(0xFF00A750);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenDark = Color(0xFF067A46);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
}

class GameZoneCmr {
  static const List<String> fontFallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static bool mobile(BuildContext context) => MediaQuery.of(context).size.width < 720;

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
      iconTheme: iconTheme ?? const IconThemeData(color: GzColors.text, size: 20),
      actionsIconTheme: actionsIconTheme ?? const IconThemeData(color: GzColors.text, size: 20),
      titleSpacing: 4,
      title: DefaultTextStyle.merge(
        style: titleTextStyle ?? const TextStyle(
          color: GzColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          fontFamily: 'Segoe UI',
          fontFamilyFallback: fontFallback,
        ),
        child: title ?? const SizedBox.shrink(),
      ),
      actions: actions,
    );
  }

  static Widget page(BuildContext context, {required Widget child}) {
    final compact = mobile(context);
    return Container(
      color: GzColors.bg,
      padding: EdgeInsets.all(compact ? 8 : 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 22 : 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 22 : 24),
            border: Border.all(color: GzColors.divider),
          ),
          child: child,
        ),
      ),
    );
  }

  static EdgeInsets listPadding(BuildContext context) {
    final compact = mobile(context);
    return EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 18, compact ? 14 : 18, compact ? 22 : 26);
  }

  static BoxDecoration card({Color color = Colors.white, Color? borderColor, double radius = 20}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? GzColors.divider),
    );
  }

  static Widget header({
    required String title,
    required String subtitle,
    IconData icon = Icons.sports_esports_rounded,
    List<Widget> stats = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: card(color: GzColors.greenSoft2, borderColor: GzColors.divider, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GzColors.divider),
                ),
                child: Icon(icon, color: GzColors.green, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: GzColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: GzColors.subtle,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: stats),
          ],
        ],
      ),
    );
  }

  static Widget stat(String title, String value, {Color color = GzColors.green}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GzColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GzColors.subtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? GzColors.graphite : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? GzColors.graphite : GzColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? Colors.white : GzColors.green),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : GzColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: content),
    );
  }

  static Widget sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: GzColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: GzColors.subtle,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: card(color: Colors.white, radius: 22),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: GzColors.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 28, color: GzColors.green),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: GzColors.text),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: GzColors.subtle, height: 1.4, fontWeight: FontWeight.w600),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }

  static ButtonStyle primaryButton() => ElevatedButton.styleFrom(
        backgroundColor: GzColors.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      );

  static ButtonStyle secondaryButton() => OutlinedButton.styleFrom(
        foregroundColor: GzColors.text,
        side: const BorderSide(color: GzColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      );
}
