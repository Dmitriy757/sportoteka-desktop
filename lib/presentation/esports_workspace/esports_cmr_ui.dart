import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class EsportsColors {
  static const bg = Colors.white;
  static const card = Colors.white;
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF374151);
  static const subtle = Color(0xFF6B7280);
  static const line = Color(0xFFE9ECEA);
  static const soft = Color(0xFFF4F6F4);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const orange = Color(0xFFEA580C);
  static const orangeSoft = Color(0xFFFFF1E8);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF3E8FF);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFEECEC);
}

BoxDecoration esportsCardDecoration({double radius = 16}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: EsportsColors.line.withOpacity(.55), width: .7),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.015),
          blurRadius: 16,
          spreadRadius: -11,
          offset: const Offset(0, 9),
        ),
      ],
    );

String esportsText(dynamic value) {
  final s = '${value ?? ''}'.trim();
  return s.toLowerCase() == 'null' ? '' : s;
}

int esportsInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim()) ?? 0;

bool esportsBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value > 0;
  final s = '${value ?? ''}'.trim().toLowerCase();
  return {'1', 'true', 'yes', 'active', 'enabled', 'live'}.contains(s);
}

class EsportsPanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const EsportsPanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.custom(
                  size: 19,
                  weight: FontWeight.w600,
                  color: EsportsColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.custom(
                  size: 11.5,
                  weight: FontWeight.w400,
                  color: EsportsColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class EsportsActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;

  const EsportsActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? EsportsColors.red
        : primary
            ? EsportsColors.green
            : EsportsColors.soft;
    final fg = (primary || danger) ? Colors.white : EsportsColors.text;
    return Material(
      color: onTap == null ? bg.withOpacity(.45) : bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Text(label, style: AppTypography.action(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class EsportsMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? caption;

  const EsportsMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: esportsCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: EsportsColors.greenDark),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.custom(
              size: 22,
              weight: FontWeight.w600,
              color: EsportsColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.captionMedium(color: EsportsColors.muted)),
          if ((caption ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: AppTypography.custom(
                size: 9.8,
                weight: FontWeight.w400,
                color: EsportsColors.subtle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EsportsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  const EsportsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: esportsCardDecoration(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EsportsColors.greenSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: EsportsColors.greenDark, size: 25),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.custom(
                  size: 16,
                  weight: FontWeight.w600,
                  color: EsportsColors.text,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.custom(
                  size: 11.5,
                  weight: FontWeight.w400,
                  color: EsportsColors.muted,
                  height: 1.45,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EsportsStatusPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool danger;

  const EsportsStatusPill({
    super.key,
    required this.label,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? EsportsColors.redSoft
        : active
            ? EsportsColors.greenSoft
            : EsportsColors.soft;
    final fg = danger
        ? EsportsColors.red
        : active
            ? EsportsColors.greenDark
            : EsportsColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: AppTypography.custom(size: 10, weight: FontWeight.w600, color: fg),
      ),
    );
  }
}

TextStyle esportsFieldTextStyle({Color color = EsportsColors.text}) =>
    AppTypography.custom(
      size: 11.5,
      weight: FontWeight.w500,
      color: color,
      height: 1.2,
    ).copyWith(fontFamily: AppTypography.fontFamily);

TextStyle esportsFieldHintStyle({Color color = EsportsColors.muted}) =>
    AppTypography.custom(
      size: 10.5,
      weight: FontWeight.w400,
      color: color,
      height: 1.2,
    ).copyWith(fontFamily: AppTypography.fontFamily);

InputDecoration esportsInputDecoration(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 17, color: EsportsColors.muted),
      filled: true,
      fillColor: EsportsColors.soft,
      isDense: true,
      labelStyle: esportsFieldHintStyle(),
      floatingLabelStyle: esportsFieldHintStyle(color: EsportsColors.greenDark).copyWith(fontWeight: FontWeight.w600),
      hintStyle: esportsFieldHintStyle(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: EsportsColors.line, width: .7),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: EsportsColors.greenDark, width: .9),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: EsportsColors.line, width: .7),
      ),
    );
