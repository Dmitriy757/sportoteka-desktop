import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Единая типографика Sportoteka без обязательного BuildContext.
///
/// Основной шрифт: Inter.
/// Рекомендуемые файлы:
/// - assets/fonts/Inter-Regular.ttf  -> 400
/// - assets/fonts/Inter-SemiBold.ttf -> 600
/// - assets/fonts/Inter-Bold.ttf     -> 700
///
/// Для отдельных экранов можно передавать [scale]:
/// - mobile: 1.0
/// - tablet: 0.95
/// - desktop: 0.92
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const List<String> fontFallback = <String>[
    'SF Pro Text',
    'SF Pro Display',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  static const Color primaryText = Color(0xFF0B0F14);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color mutedText = Color(0xFF9CA3AF);

  static TextStyle screenTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 18,
        weight: FontWeight.w700,
        color: color,
        height: 1.14,
        letterSpacing: -0.04,
        scale: scale,
      );

  static TextStyle sectionTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 16,
        weight: FontWeight.w600,
        color: color,
        height: 1.20,
        letterSpacing: 0,
        scale: scale,
      );

  static TextStyle itemTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 15,
        weight: FontWeight.w600,
        color: color,
        height: 1.22,
        letterSpacing: 0,
        scale: scale,
      );

  static TextStyle body({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 14,
        weight: FontWeight.w400,
        color: color,
        height: 1.36,
        scale: scale,
      );

  static TextStyle bodyMedium({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 14,
        weight: FontWeight.w600,
        color: color,
        height: 1.34,
        scale: scale,
      );

  static TextStyle secondary({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.5,
        weight: FontWeight.w400,
        color: color,
        height: 1.30,
        scale: scale,
      );

  static TextStyle secondaryMedium({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.5,
        weight: FontWeight.w600,
        color: color,
        height: 1.30,
        scale: scale,
      );

  static TextStyle caption({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.5,
        weight: FontWeight.w400,
        color: color,
        height: 1.18,
        scale: scale,
      );

  static TextStyle captionMedium({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.5,
        weight: FontWeight.w600,
        color: color,
        height: 1.22,
        scale: scale,
      );

  static TextStyle action({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 13,
        weight: FontWeight.w600,
        color: color,
        height: 1.16,
        scale: scale,
      );

  static TextStyle actionStrong({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 13,
        weight: FontWeight.w700,
        color: color,
        height: 1.12,
        scale: scale,
      );

  static TextStyle metric({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 22,
        weight: FontWeight.w600,
        color: color,
        height: 1.08,
        letterSpacing: -0.04,
        scale: scale,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle metricStrong({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 22,
        weight: FontWeight.w700,
        color: color,
        height: 1.08,
        letterSpacing: -0.04,
        scale: scale,
        features: const <FontFeature>[
          FontFeature.tabularFigures(),
        ],
      );

  static TextStyle custom({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = primaryText,
    double height = 1.2,
    double letterSpacing = 0,
    double scale = 1,
    List<FontFeature>? features,
  }) =>
      TextStyle(
        color: color,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size * scale,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: features,
      );
}
