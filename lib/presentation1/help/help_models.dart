import 'package:flutter/material.dart';

class HelpTipItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<HelpTipSection> sections;

  const HelpTipItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.sections,
  });
}

class HelpTipSection {
  final String heading;
  final List<String> bullets;

  const HelpTipSection({
    required this.heading,
    required this.bullets,
  });
}