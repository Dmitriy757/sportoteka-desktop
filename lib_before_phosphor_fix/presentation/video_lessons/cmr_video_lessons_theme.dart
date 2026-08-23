import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class CmrVideoColors {
  static const bg = Color(0xFFF6F7F6);
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
  static const greenBorder = Color(0xFFD7F0E2);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF1F1);
}

class CmrVideoText {
  static TextStyle title(double size) => AppTypography.custom(
    size: size, weight: FontWeight.w600, color: CmrVideoColors.text,
    height: 1.18, letterSpacing: 0,
    features: const [FontFeature.tabularFigures()],
  );
  static TextStyle body(double size) => AppTypography.custom(
    size: size, weight: FontWeight.w400, color: CmrVideoColors.muted,
    height: 1.32, letterSpacing: 0,
  );
  static TextStyle action([Color color = CmrVideoColors.text]) => AppTypography.custom(
    size: 11.8, weight: FontWeight.w600, color: color, letterSpacing: 0,
  );
  static TextStyle caption() => AppTypography.custom(
    size: 10.8, weight: FontWeight.w500, color: CmrVideoColors.subtle,
    height: 1.18, letterSpacing: 0,
  );
}

class CmrVideoDecor {
  static List<BoxShadow> get windowShadow => [
    BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 28, spreadRadius: -18, offset: const Offset(0, 16)),
  ];
  static BoxDecoration window({double radius = 20}) => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(radius), boxShadow: windowShadow,
  );
  static BoxDecoration soft({bool active = false, double radius = 12}) => BoxDecoration(
    color: active ? CmrVideoColors.greenSoft : CmrVideoColors.soft,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: active ? CmrVideoColors.greenBorder : Colors.transparent, width: active ? .7 : 0),
  );
}

class CmrVideoIconButton extends StatelessWidget {
  final IconData icon; final String tooltip; final VoidCallback? onTap; final bool accent;
  const CmrVideoIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.accent = false});
  @override Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(width: 36, height: 36, decoration: CmrVideoDecor.soft(active: accent, radius: 10),
        child: Icon(icon, size: 17, color: accent ? CmrVideoColors.green : CmrVideoColors.text)),
    )),
  );
}
