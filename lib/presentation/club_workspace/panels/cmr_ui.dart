import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class CmrColors {
  static const bg = Color(0xFFF4F7FB);
  static const surface = Colors.white;
  static const text = Color(0xFF172033);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE4EAF2);
  static const blue = Color(0xFF1463FF);
  static const blueDark = Color(0xFF0E3F9E);
  static const green = Color(0xFF18A058);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const violet = Color(0xFF7C3AED);
  static const cyan = Color(0xFF0891B2);
}

class CmrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  const CmrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: CmrColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CmrColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CmrSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const CmrSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.screenTitle(color: CmrColors.text),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.secondaryMedium(color: CmrColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class CmrPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const CmrPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = CmrColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTypography.actionStrong(color: Colors.white),
      ),
    );
  }
}

class CmrGhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const CmrGhostButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: CmrColors.text,
        side: const BorderSide(color: CmrColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTypography.action(color: CmrColors.text),
      ),
    );
  }
}

class CmrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const CmrEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CmrCard(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: CmrColors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: CmrColors.blue, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.emptyTitle(color: CmrColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.emptyText(color: CmrColors.muted),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

int cmrInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

String cmrStr(dynamic v, [String fallback = '']) {
  final s = v?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return fallback;
  return s;
}

String? cmrImage(dynamic v) {
  final raw = cmrStr(v);
  if (raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
  return 'https://sportotekaapp.ru/$raw';
}
