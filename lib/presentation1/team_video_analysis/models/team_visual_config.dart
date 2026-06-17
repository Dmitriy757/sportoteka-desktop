import 'package:flutter/material.dart';

enum AnalysisSideTag { home, away }

class TeamVisualConfig {
  final AnalysisSideTag sideTag;
  final String displayName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;

  const TeamVisualConfig({
    required this.sideTag,
    required this.displayName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
  });

  TeamVisualConfig copyWith({
    AnalysisSideTag? sideTag,
    String? displayName,
    Color? primaryColor,
    Color? secondaryColor,
    Color? textColor,
  }) {
    return TeamVisualConfig(
      sideTag: sideTag ?? this.sideTag,
      displayName: displayName ?? this.displayName,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      textColor: textColor ?? this.textColor,
    );
  }
}