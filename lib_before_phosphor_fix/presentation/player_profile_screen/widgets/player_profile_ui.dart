import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class PpColors {
  static const bg = Color(0xFFF6F7F6);
  static const panel = Colors.white;
  static const soft = Color(0xFFFAFBFA);
  static const soft2 = Color(0xFFF3F5F4);
  static const line = Color(0xFFE9ECEA);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF667085);
  static const muted2 = Color(0xFF98A2B3);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
  static const red = Color(0xFFD92D20);
  static const amber = Color(0xFFF59E0B);
}

class PpText {
  static TextStyle title(double size) => AppTypography.custom(size: size, weight: FontWeight.w600, color: PpColors.text, height: 1.18, features: const [FontFeature.tabularFigures()]);
  static TextStyle body(double size, {Color color = PpColors.muted, FontWeight weight = FontWeight.w400}) => AppTypography.custom(size: size, weight: weight, color: color, height: 1.32);
  static TextStyle value(double size) => AppTypography.custom(size: size, weight: FontWeight.w600, color: PpColors.text, height: 1.1, features: const [FontFeature.tabularFigures()]);
}

class PpSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  const PpSurface({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = PpColors.soft, this.radius = 12});
  @override Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)), child: child);
}

class PpSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PpSectionTitle({super.key, required this.title, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: PpText.title(15.5)), if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: PpText.body(11.5))]])), if (trailing != null) trailing!]);
}

class PpMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  const PpMetric({super.key, required this.label, required this.value, this.note});
  @override Widget build(BuildContext context) => PpSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: PpText.body(10.8)), const SizedBox(height: 8), Text(value, style: PpText.value(20)), if (note != null) ...[const SizedBox(height: 4), Text(note!, style: PpText.body(10.2))]]));
}

class PpActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  const PpActionRow({super.key, required this.icon, required this.title, required this.subtitle, this.onTap, this.danger = false});
  @override Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: danger ? const Color(0xFFFFF1F1) : PpColors.greenSoft, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: danger ? PpColors.red : PpColors.green)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: PpText.body(12.2, color: danger ? PpColors.red : PpColors.text, weight: FontWeight.w600)), const SizedBox(height: 2), Text(subtitle, style: PpText.body(10.5))])), Icon(Icons.chevron_right_rounded, size: 18, color: PpColors.muted)]))));
}

class PpEmpty extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const PpEmpty({super.key, required this.title, required this.text, this.icon = Icons.inbox_outlined});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 32, color: PpColors.muted), const SizedBox(height: 10), Text(title, style: PpText.title(14)), const SizedBox(height: 4), Text(text, textAlign: TextAlign.center, style: PpText.body(11.5))])));
}
