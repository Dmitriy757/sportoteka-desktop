import 'package:flutter/material.dart';

class TgSectionTitle extends StatelessWidget {
  const TgSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TgSubTitle extends StatelessWidget {
  const TgSubTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class TgChoice2<T> extends StatelessWidget {
  const TgChoice2({
    super.key,
    required this.value,
    required this.aValue,
    required this.bValue,
    required this.aText,
    required this.bText,
    required this.onChanged,
    this.aIcon,
    this.bIcon,
  });

  final T value;
  final T aValue;
  final T bValue;
  final String aText;
  final String bText;
  final void Function(T v) onChanged;
  final Widget? aIcon;
  final Widget? bIcon;

  @override
  Widget build(BuildContext context) {
    Widget item(T v, String text, {Widget? icon}) {
      final active = value == v;
      return InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE7F3EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                SizedBox(width: 22, height: 22, child: icon),
                const SizedBox(width: 10),
              ],
              Text(text, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        item(aValue, aText, icon: aIcon),
        item(bValue, bText, icon: bIcon),
      ],
    );
  }
}

class TgChoice3<T> extends StatelessWidget {
  const TgChoice3({
    super.key,
    required this.value,
    required this.aValue,
    required this.bValue,
    required this.cValue,
    required this.aText,
    required this.bText,
    required this.cText,
    required this.onChanged,
    this.aIcon,
    this.bIcon,
    this.cIcon,
  });

  final T value;
  final T aValue;
  final T bValue;
  final T cValue;
  final String aText;
  final String bText;
  final String cText;
  final void Function(T v) onChanged;

  final Widget? aIcon;
  final Widget? bIcon;
  final Widget? cIcon;

  @override
  Widget build(BuildContext context) {
    Widget item(T v, String text, {Widget? icon}) {
      final active = value == v;
      return InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE7F3EA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                SizedBox(width: 22, height: 22, child: icon),
                const SizedBox(width: 10),
              ],
              Text(text, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        item(aValue, aText, icon: aIcon),
        item(bValue, bText, icon: bIcon),
        item(cValue, cText, icon: cIcon),
      ],
    );
  }
}

class TgStepper extends StatelessWidget {
  const TgStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final void Function(double v) onChanged;

  @override
  Widget build(BuildContext context) {
    double clamp(double v) => v < min ? min : (v > max ? max : v);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF7A7A7A)),
          ),
        ),
        Container(
          width: 92,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: () => onChanged(clamp(value - step)),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: () => onChanged(clamp(value + step)),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TgColorRow extends StatelessWidget {
  const TgColorRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowTransparent = false,
  });

  final String label;
  final Color value;
  final void Function(Color c) onChanged;
  final bool allowTransparent;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      if (allowTransparent) Colors.transparent,
      const Color(0xFF2E2E2E),
      Colors.white,
      const Color(0xFFE53935),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFDD835),
      const Color(0xFF8E24AA),
    ];

    Widget sw(Color c) {
      final active = c.value == value.value;
      return InkWell(
        onTap: () => onChanged(c),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 34,
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          decoration: BoxDecoration(
            color: c == Colors.transparent ? Colors.transparent : c,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFF2E7D32) : const Color(0xFFE6E6E6),
              width: active ? 2 : 1,
            ),
          ),
          child: c == Colors.transparent
              ? const Center(
                  child: Icon(Icons.block, size: 18, color: Color(0xFF9E9E9E)),
                )
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF7A7A7A))),
        const SizedBox(height: 10),
        Wrap(children: colors.map(sw).toList()),
      ],
    );
  }
}
