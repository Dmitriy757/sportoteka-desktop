import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Единая типографика Sportoteka / CMR.
///
/// Основной шрифт: Inter.
///
/// Шкала специально остаётся компактной: мобильная версия должна быть
/// читаемой, но не выглядеть как крупный consumer UI.
///
/// Рекомендуемый scale:
/// - mobile: 1.00
/// - tablet: 0.97
/// - desktop: 0.95
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const List<String> fontFallback = <String>[
    'SF Pro Text',
    'SF Pro Display',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];


  // ---------------------------------------------------------------------------
  // CONST-РАЗМЕРЫ
  // ---------------------------------------------------------------------------
  // Эти значения нужны для старых/сложных UI-компонентов, где TextStyle
  // находится внутри const-дерева. Они полностью совпадают с семантическими
  // методами ниже и позволяют централизовать размер без runtime-вызова метода.
  static const double screenTitleSize = 16.5;
  static const double sectionTitleSize = 14.5;
  static const double subsectionTitleSize = 13.5;
  static const double itemTitleSize = 13.2;
  static const double bodySize = 12.8;
  static const double secondarySize = 11.8;
  static const double captionSize = 10.8;
  static const double menuTitleSize = 12.2;
  static const double menuSubtitleSize = 10.7;
  static const double menuGroupSize = 9.4;
  static const double tabSize = 11.8;
  static const double actionSize = 12.2;
  static const double chipSize = 10.8;
  static const double badgeSize = 9.2;
  static const double formLabelSize = 11.8;
  static const double formTextSize = 12.8;
  static const double formHintSize = 10.8;
  static const double commentTextSize = 12.6;
  static const double commentMetaSize = 10.5;
  static const double documentTitleSize = 13.2;
  static const double documentMetaSize = 10.8;

  static const Color primaryText = Color(0xFF0B0F14);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color mutedText = Color(0xFF9CA3AF);

  /// Можно использовать там, где экран сам знает ширину.
  static double scaleForWidth(double width) {
    if (width < 640) return 1.00;
    if (width < 1180) return 0.97;
    return 0.95;
  }

  // ---------------------------------------------------------------------------
  // ИЕРАРХИЯ ЭКРАНА
  // ---------------------------------------------------------------------------

  /// Главный заголовок экрана / крупной шапки.
  /// Примеры: «Документы», «Тестирование», «Профиль игрока».
  static TextStyle screenTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 16.5,
        weight: FontWeight.w700,
        color: color,
        height: 1.16,
        letterSpacing: -0.02,
        scale: scale,
      );

  /// Заголовок основного раздела внутри экрана.
  static TextStyle sectionTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 14.5,
        weight: FontWeight.w600,
        color: color,
        height: 1.20,
        scale: scale,
      );

  /// Заголовок подраздела / смыслового блока.
  static TextStyle subsectionTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 13.5,
        weight: FontWeight.w600,
        color: color,
        height: 1.22,
        scale: scale,
      );

  /// Название карточки, записи, файла, теста, тренировки и т. п.
  static TextStyle itemTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 13.2,
        weight: FontWeight.w600,
        color: color,
        height: 1.22,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // ОСНОВНОЙ ТЕКСТ
  // ---------------------------------------------------------------------------

  static TextStyle body({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.38,
        scale: scale,
      );

  static TextStyle bodyMedium({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.34,
        scale: scale,
      );

  /// Вторичная строка: описание, пояснение, дата + контекст.
  static TextStyle secondary({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.32,
        scale: scale,
      );

  static TextStyle secondaryMedium({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.30,
        scale: scale,
      );

  /// Самая мелкая регулярная подпись. Ниже этого размера основной UI лучше
  /// не опускать; исключения — badge / micro label.
  static TextStyle caption({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.24,
        scale: scale,
      );

  static TextStyle captionMedium({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.24,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // МОБИЛЬНОЕ МЕНЮ / НАВИГАЦИЯ
  // ---------------------------------------------------------------------------

  /// Основная строка пункта меню.
  static TextStyle menuTitle({
    Color color = primaryText,
    double scale = 1,
    FontWeight weight = FontWeight.w600,
  }) =>
      custom(
        size: 12.2,
        weight: weight,
        color: color,
        height: 1.16,
        scale: scale,
      );

  /// Описание под пунктом меню.
  static TextStyle menuSubtitle({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.7,
        weight: FontWeight.w400,
        color: color,
        height: 1.24,
        scale: scale,
      );

  /// Заголовок группы в меню: «ОСНОВНОЕ», «АККАУНТ» и т. п.
  static TextStyle menuGroup({
    Color color = mutedText,
    double scale = 1,
  }) =>
      custom(
        size: 9.4,
        weight: FontWeight.w700,
        color: color,
        height: 1.12,
        letterSpacing: .45,
        scale: scale,
      );

  /// Горизонтальные вкладки / секции профиля.
  static TextStyle tab({
    Color color = primaryText,
    double scale = 1,
    bool active = false,
  }) =>
      custom(
        size: 11.8,
        weight: active ? FontWeight.w600 : FontWeight.w500,
        color: color,
        height: 1.16,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // КНОПКИ / ДЕЙСТВИЯ / ЧИПЫ
  // ---------------------------------------------------------------------------

  static TextStyle action({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.2,
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
        size: 12.2,
        weight: FontWeight.w700,
        color: color,
        height: 1.14,
        scale: scale,
      );

  static TextStyle chip({
    Color color = secondaryText,
    double scale = 1,
    bool active = false,
  }) =>
      custom(
        size: 10.8,
        weight: active ? FontWeight.w600 : FontWeight.w500,
        color: color,
        height: 1.10,
        scale: scale,
      );

  /// PRO / NEW / LIVE и другие очень короткие badge.
  static TextStyle badge({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 9.2,
        weight: FontWeight.w700,
        color: color,
        height: 1,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // ФОРМЫ / ДОБАВЛЕНИЕ ДАННЫХ
  // ---------------------------------------------------------------------------

  static TextStyle formLabel({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.20,
        scale: scale,
      );

  static TextStyle formText({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.34,
        scale: scale,
      );

  static TextStyle formHint({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.28,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // КОММЕНТАРИИ / ЗАМЕТКИ
  // ---------------------------------------------------------------------------

  static TextStyle commentAuthor({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.18,
        scale: scale,
      );

  static TextStyle commentText({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 12.6,
        weight: FontWeight.w400,
        color: color,
        height: 1.38,
        scale: scale,
      );

  static TextStyle commentMeta({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.5,
        weight: FontWeight.w400,
        color: color,
        height: 1.18,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // ДОКУМЕНТЫ / ФАЙЛЫ
  // ---------------------------------------------------------------------------

  static TextStyle documentTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 13.2,
        weight: FontWeight.w600,
        color: color,
        height: 1.22,
        scale: scale,
      );

  static TextStyle documentMeta({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 10.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.24,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // EMPTY / STATUS
  // ---------------------------------------------------------------------------

  static TextStyle emptyTitle({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 14,
        weight: FontWeight.w600,
        color: color,
        height: 1.20,
        scale: scale,
      );

  static TextStyle emptyText({
    Color color = secondaryText,
    double scale = 1,
  }) =>
      custom(
        size: 11.8,
        weight: FontWeight.w400,
        color: color,
        height: 1.34,
        scale: scale,
      );

  // ---------------------------------------------------------------------------
  // МЕТРИКИ
  // ---------------------------------------------------------------------------

  static TextStyle metric({
    Color color = primaryText,
    double scale = 1,
  }) =>
      custom(
        size: 21,
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
        size: 21,
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
