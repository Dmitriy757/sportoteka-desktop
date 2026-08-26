import 'package:flutter/material.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'cmr_calendar_panel.dart';

/// Полноэкранная точка входа календаря.
///
/// Старый TeamCalendarScreen содержал отдельные bottom-sheet редакторы.
/// Теперь он является только оболочкой над тем же CMR workspace, поэтому
/// создание, редактирование, посещаемость и оценки не меняют механику
/// при открытии календаря на весь экран.
class TeamCalendarScreen extends StatelessWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const TeamCalendarScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.clubId = 0,
    this.clubName = '',
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
        textTheme: base.textTheme
            .apply(
              fontFamily: AppTypography.fontFamily,
              bodyColor: const Color(0xFF0B0F14),
              displayColor: const Color(0xFF0B0F14),
            )
            .copyWith(
              titleLarge: AppTypography.screenTitle(),
              titleMedium: AppTypography.sectionTitle(),
              titleSmall: AppTypography.subsectionTitle(),
              bodyLarge: AppTypography.body(),
              bodyMedium: AppTypography.body(),
              bodySmall: AppTypography.caption(),
              labelLarge: AppTypography.action(),
            ),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: const Color(0xFF0B0F14),
          displayColor: const Color(0xFF0B0F14),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F7),
        body: SafeArea(
          child: CmrCalendarPanel(
            teamId: teamId,
            teamName: teamName,
            clubId: clubId,
            clubName: clubName,
            allowOpenFull: false,
          ),
        ),
      ),
    );
  }
}
