// lib/presentation/my_profile_screen/my_profile_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/widgets/player_skills_fifa_stub.dart';
import 'package:sportoteka/presentation/reels_screen/upload_reel_screen.dart';
import 'package:sportoteka/presentation/reels_screen/user_reels_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/profile_reel_widget.dart';

// =============================
// ЦВЕТОВАЯ ПАЛИТРА (ОСТАВЛЯЕМ)
// =============================
class ProfilePalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const background = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
}

// =============================
// МОДЕЛЬ ДИЗАЙНА ПРОФИЛЯ (НОВЫЙ КОД)
// =============================
class ProfileDesign {
  // === Основные цвета ===
  int primaryColorValue;
  int secondaryColorValue;
  int accentColorValue;
  int backgroundColorValue;
  int surfaceColorValue;
  int cardColorValue;
  int textPrimaryColorValue;
  int textSecondaryColorValue;
  int textTertiaryColorValue;

  // === Текст ===
  String fontFamily;
  double titleFontSize;
  double headingFontSize;
  double bodyFontSize;
  double smallFontSize;
  FontWeight titleWeight;
  FontWeight headingWeight;
  FontWeight bodyWeight;

  // === Размеры и скругления ===
  double avatarSize;
  double avatarBorderWidth;
  double cardRadius;
  double buttonRadius;
  double spacing;
  double contentPadding;

  // === Аватар ===
  int avatarBorderColorValue;
  bool avatarGlowEnabled;
  double avatarGlowRadius;
  double avatarGlowOpacity;

  // === Градиенты ===
  bool headerGradientEnabled;
  List<int> headerGradientColors;
  double headerGradientBeginX;
  double headerGradientBeginY;
  double headerGradientEndX;
  double headerGradientEndY;

  // === Тени ===
  bool cardShadowEnabled;
  double cardShadowBlurRadius;
  double cardShadowSpreadRadius;
  double cardShadowOffsetX;
  double cardShadowOffsetY;
  int cardShadowColorValue;
  double cardShadowOpacity;

  bool avatarShadowEnabled;
  double avatarShadowBlurRadius;
  double avatarShadowSpreadRadius;
  double avatarShadowOffsetX;
  double avatarShadowOffsetY;
  int avatarShadowColorValue;
  double avatarShadowOpacity;

  // === Блоки и видимость ===
  List<ProfileBlock> blocks;
  Map<String, bool> sectionVisibility;
  Map<String, int> sectionOrder;

  // === Статистика ===
  bool statsCompactMode;
  bool statsShowLabels;
  bool statsShowIcons;

  // === Анимации ===
  bool enableHoverEffects;
  bool enablePulseEffects;

  ProfileDesign({
    required this.primaryColorValue,
    required this.secondaryColorValue,
    required this.accentColorValue,
    required this.backgroundColorValue,
    required this.surfaceColorValue,
    required this.cardColorValue,
    required this.textPrimaryColorValue,
    required this.textSecondaryColorValue,
    required this.textTertiaryColorValue,
    required this.fontFamily,
    required this.titleFontSize,
    required this.headingFontSize,
    required this.bodyFontSize,
    required this.smallFontSize,
    required this.titleWeight,
    required this.headingWeight,
    required this.bodyWeight,
    required this.avatarSize,
    required this.avatarBorderWidth,
    required this.cardRadius,
    required this.buttonRadius,
    required this.spacing,
    required this.contentPadding,
    required this.avatarBorderColorValue,
    required this.avatarGlowEnabled,
    required this.avatarGlowRadius,
    required this.avatarGlowOpacity,
    required this.headerGradientEnabled,
    required this.headerGradientColors,
    required this.headerGradientBeginX,
    required this.headerGradientBeginY,
    required this.headerGradientEndX,
    required this.headerGradientEndY,
    required this.cardShadowEnabled,
    required this.cardShadowBlurRadius,
    required this.cardShadowSpreadRadius,
    required this.cardShadowOffsetX,
    required this.cardShadowOffsetY,
    required this.cardShadowColorValue,
    required this.cardShadowOpacity,
    required this.avatarShadowEnabled,
    required this.avatarShadowBlurRadius,
    required this.avatarShadowSpreadRadius,
    required this.avatarShadowOffsetX,
    required this.avatarShadowOffsetY,
    required this.avatarShadowColorValue,
    required this.avatarShadowOpacity,
    required this.blocks,
    required this.sectionVisibility,
    required this.sectionOrder,
    required this.statsCompactMode,
    required this.statsShowLabels,
    required this.statsShowIcons,
    required this.enableHoverEffects,
    required this.enablePulseEffects,
  });

  // ========== ВАЖНО: МЕТОД COPYWITH ==========
  ProfileDesign copyWith({
    int? primaryColorValue,
    int? secondaryColorValue,
    int? accentColorValue,
    int? backgroundColorValue,
    int? surfaceColorValue,
    int? cardColorValue,
    int? textPrimaryColorValue,
    int? textSecondaryColorValue,
    int? textTertiaryColorValue,
    String? fontFamily,
    double? titleFontSize,
    double? headingFontSize,
    double? bodyFontSize,
    double? smallFontSize,
    FontWeight? titleWeight,
    FontWeight? headingWeight,
    FontWeight? bodyWeight,
    double? avatarSize,
    double? avatarBorderWidth,
    double? cardRadius,
    double? buttonRadius,
    double? spacing,
    double? contentPadding,
    int? avatarBorderColorValue,
    bool? avatarGlowEnabled,
    double? avatarGlowRadius,
    double? avatarGlowOpacity,
    bool? headerGradientEnabled,
    List<int>? headerGradientColors,
    double? headerGradientBeginX,
    double? headerGradientBeginY,
    double? headerGradientEndX,
    double? headerGradientEndY,
    bool? cardShadowEnabled,
    double? cardShadowBlurRadius,
    double? cardShadowSpreadRadius,
    double? cardShadowOffsetX,
    double? cardShadowOffsetY,
    int? cardShadowColorValue,
    double? cardShadowOpacity,
    bool? avatarShadowEnabled,
    double? avatarShadowBlurRadius,
    double? avatarShadowSpreadRadius,
    double? avatarShadowOffsetX,
    double? avatarShadowOffsetY,
    int? avatarShadowColorValue,
    double? avatarShadowOpacity,
    List<ProfileBlock>? blocks,
    Map<String, bool>? sectionVisibility,
    Map<String, int>? sectionOrder,
    bool? statsCompactMode,
    bool? statsShowLabels,
    bool? statsShowIcons,
    bool? enableHoverEffects,
    bool? enablePulseEffects,
  }) {
    return ProfileDesign(
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      surfaceColorValue: surfaceColorValue ?? this.surfaceColorValue,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      textPrimaryColorValue: textPrimaryColorValue ?? this.textPrimaryColorValue,
      textSecondaryColorValue: textSecondaryColorValue ?? this.textSecondaryColorValue,
      textTertiaryColorValue: textTertiaryColorValue ?? this.textTertiaryColorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      headingFontSize: headingFontSize ?? this.headingFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      smallFontSize: smallFontSize ?? this.smallFontSize,
      titleWeight: titleWeight ?? this.titleWeight,
      headingWeight: headingWeight ?? this.headingWeight,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      avatarSize: avatarSize ?? this.avatarSize,
      avatarBorderWidth: avatarBorderWidth ?? this.avatarBorderWidth,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      spacing: spacing ?? this.spacing,
      contentPadding: contentPadding ?? this.contentPadding,
      avatarBorderColorValue: avatarBorderColorValue ?? this.avatarBorderColorValue,
      avatarGlowEnabled: avatarGlowEnabled ?? this.avatarGlowEnabled,
      avatarGlowRadius: avatarGlowRadius ?? this.avatarGlowRadius,
      avatarGlowOpacity: avatarGlowOpacity ?? this.avatarGlowOpacity,
      headerGradientEnabled: headerGradientEnabled ?? this.headerGradientEnabled,
      headerGradientColors: headerGradientColors ?? this.headerGradientColors,
      headerGradientBeginX: headerGradientBeginX ?? this.headerGradientBeginX,
      headerGradientBeginY: headerGradientBeginY ?? this.headerGradientBeginY,
      headerGradientEndX: headerGradientEndX ?? this.headerGradientEndX,
      headerGradientEndY: headerGradientEndY ?? this.headerGradientEndY,
      cardShadowEnabled: cardShadowEnabled ?? this.cardShadowEnabled,
      cardShadowBlurRadius: cardShadowBlurRadius ?? this.cardShadowBlurRadius,
      cardShadowSpreadRadius: cardShadowSpreadRadius ?? this.cardShadowSpreadRadius,
      cardShadowOffsetX: cardShadowOffsetX ?? this.cardShadowOffsetX,
      cardShadowOffsetY: cardShadowOffsetY ?? this.cardShadowOffsetY,
      cardShadowColorValue: cardShadowColorValue ?? this.cardShadowColorValue,
      cardShadowOpacity: cardShadowOpacity ?? this.cardShadowOpacity,
      avatarShadowEnabled: avatarShadowEnabled ?? this.avatarShadowEnabled,
      avatarShadowBlurRadius: avatarShadowBlurRadius ?? this.avatarShadowBlurRadius,
      avatarShadowSpreadRadius: avatarShadowSpreadRadius ?? this.avatarShadowSpreadRadius,
      avatarShadowOffsetX: avatarShadowOffsetX ?? this.avatarShadowOffsetX,
      avatarShadowOffsetY: avatarShadowOffsetY ?? this.avatarShadowOffsetY,
      avatarShadowColorValue: avatarShadowColorValue ?? this.avatarShadowColorValue,
      avatarShadowOpacity: avatarShadowOpacity ?? this.avatarShadowOpacity,
      blocks: blocks ?? this.blocks,
      sectionVisibility: sectionVisibility ?? this.sectionVisibility,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      statsCompactMode: statsCompactMode ?? this.statsCompactMode,
      statsShowLabels: statsShowLabels ?? this.statsShowLabels,
      statsShowIcons: statsShowIcons ?? this.statsShowIcons,
      enableHoverEffects: enableHoverEffects ?? this.enableHoverEffects,
      enablePulseEffects: enablePulseEffects ?? this.enablePulseEffects,
    );
  }

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);
  Color get accentColor => Color(accentColorValue);
  Color get backgroundColor => Color(backgroundColorValue);
  Color get surfaceColor => Color(surfaceColorValue);
  Color get cardColor => Color(cardColorValue);
  Color get textPrimaryColor => Color(textPrimaryColorValue);
  Color get textSecondaryColor => Color(textSecondaryColorValue);
  Color get textTertiaryColor => Color(textTertiaryColorValue);
  Color get avatarBorderColor => Color(avatarBorderColorValue);

 factory ProfileDesign.fromJson(Map<String, dynamic> json) {
  final rawBlocks = json['blocks'];
  final rawSectionVisibility = json['sectionVisibility'];
  final rawSectionOrder = json['sectionOrder'];

  return ProfileDesign(
    primaryColorValue: json['primaryColorValue'] ?? 0xFF00A750,
    secondaryColorValue: json['secondaryColorValue'] ?? 0xFF008C40,
    accentColorValue: json['accentColorValue'] ?? 0xFF7ED321,
    backgroundColorValue: json['backgroundColorValue'] ?? 0xFFF8F9FA,
    surfaceColorValue: json['surfaceColorValue'] ?? 0xFFE8F5E9,
    cardColorValue: json['cardColorValue'] ?? 0xFFFFFFFF,
    textPrimaryColorValue: json['textPrimaryColorValue'] ?? 0xFF1A1A1A,
    textSecondaryColorValue: json['textSecondaryColorValue'] ?? 0xFF666666,
    textTertiaryColorValue: json['textTertiaryColorValue'] ?? 0xFF999999,

    fontFamily: (json['fontFamily'] ?? 'default').toString(),
    titleFontSize: (json['titleFontSize'] as num?)?.toDouble() ?? 22,
    headingFontSize: (json['headingFontSize'] as num?)?.toDouble() ?? 18,
    bodyFontSize: (json['bodyFontSize'] as num?)?.toDouble() ?? 14,
    smallFontSize: (json['smallFontSize'] as num?)?.toDouble() ?? 12,

    titleWeight: _parseFontWeight((json['titleWeight'] ?? 'w900').toString()),
    headingWeight: _parseFontWeight((json['headingWeight'] ?? 'w700').toString()),
    bodyWeight: _parseFontWeight((json['bodyWeight'] ?? 'w500').toString()),

    avatarSize: (json['avatarSize'] as num?)?.toDouble() ?? 96,
    avatarBorderWidth: (json['avatarBorderWidth'] as num?)?.toDouble() ?? 2,
    cardRadius: (json['cardRadius'] as num?)?.toDouble() ?? 16,
    buttonRadius: (json['buttonRadius'] as num?)?.toDouble() ?? 14,
    spacing: (json['spacing'] as num?)?.toDouble() ?? 12,
    contentPadding: (json['contentPadding'] as num?)?.toDouble() ?? 16,

    avatarBorderColorValue: json['avatarBorderColorValue'] ?? 0xFF00A750,
    avatarGlowEnabled: json['avatarGlowEnabled'] == true,
    avatarGlowRadius: (json['avatarGlowRadius'] as num?)?.toDouble() ?? 20,
    avatarGlowOpacity: (json['avatarGlowOpacity'] as num?)?.toDouble() ?? 0.3,

    headerGradientEnabled: json['headerGradientEnabled'] == true,
    headerGradientColors: (json['headerGradientColors'] is List)
        ? List<int>.from((json['headerGradientColors'] as List).map((e) {
            if (e is int) return e;
            return int.tryParse('$e') ?? 0xFF00A750;
          }))
        : <int>[0xFF00A750, 0xFF008C40],
    headerGradientBeginX: (json['headerGradientBeginX'] as num?)?.toDouble() ?? 0,
    headerGradientBeginY: (json['headerGradientBeginY'] as num?)?.toDouble() ?? 0,
    headerGradientEndX: (json['headerGradientEndX'] as num?)?.toDouble() ?? 1,
    headerGradientEndY: (json['headerGradientEndY'] as num?)?.toDouble() ?? 1,

    cardShadowEnabled: json['cardShadowEnabled'] != false,
    cardShadowBlurRadius: (json['cardShadowBlurRadius'] as num?)?.toDouble() ?? 8,
    cardShadowSpreadRadius: (json['cardShadowSpreadRadius'] as num?)?.toDouble() ?? 0,
    cardShadowOffsetX: (json['cardShadowOffsetX'] as num?)?.toDouble() ?? 0,
    cardShadowOffsetY: (json['cardShadowOffsetY'] as num?)?.toDouble() ?? 4,
    cardShadowColorValue: json['cardShadowColorValue'] ?? 0xFF000000,
    cardShadowOpacity: (json['cardShadowOpacity'] as num?)?.toDouble() ?? 0.05,

    avatarShadowEnabled: json['avatarShadowEnabled'] != false,
    avatarShadowBlurRadius: (json['avatarShadowBlurRadius'] as num?)?.toDouble() ?? 8,
    avatarShadowSpreadRadius: (json['avatarShadowSpreadRadius'] as num?)?.toDouble() ?? 0,
    avatarShadowOffsetX: (json['avatarShadowOffsetX'] as num?)?.toDouble() ?? 0,
    avatarShadowOffsetY: (json['avatarShadowOffsetY'] as num?)?.toDouble() ?? 4,
    avatarShadowColorValue: json['avatarShadowColorValue'] ?? 0xFF000000,
    avatarShadowOpacity: (json['avatarShadowOpacity'] as num?)?.toDouble() ?? 0.1,

    blocks: rawBlocks is List
        ? rawBlocks
            .whereType<Map>()
            .map((e) => ProfileBlock.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : ProfileBlock.defaultBlocks(),

    sectionVisibility: rawSectionVisibility is Map
        ? Map<String, bool>.from(
            rawSectionVisibility.map(
              (key, value) => MapEntry(key.toString(), value == true),
            ),
          )
        : <String, bool>{
            'posts': true,
            'reels': true,
            'feed': true,
            'skills': true,
            'team': true,
            'bio': true,
            'location': true,
            'ai': true,
            'header': true,
            'stats': true,
            'actions': true,
            'switcher': true,
            'content': true,
          },

    sectionOrder: rawSectionOrder is Map
        ? Map<String, int>.from(
            rawSectionOrder.map(
              (key, value) => MapEntry(
                key.toString(),
                value is num ? value.toInt() : int.tryParse('$value') ?? 0,
              ),
            ),
          )
        : <String, int>{
            'header': 0,
            'stats': 1,
            'actions': 2,
            'team': 3,
            'ai': 4,
            'skills': 5,
            'bio': 6,
            'location': 7,
            'switcher': 8,
            'content': 9,
          },

    statsCompactMode: json['statsCompactMode'] == true,
    statsShowLabels: json['statsShowLabels'] != false,
    statsShowIcons: json['statsShowIcons'] != false,
    enableHoverEffects: json['enableHoverEffects'] == true,
    enablePulseEffects: json['enablePulseEffects'] == true,
  );
}
  static FontWeight _parseFontWeight(String value) {
    switch (value) {
      case 'w100': return FontWeight.w100;
      case 'w200': return FontWeight.w200;
      case 'w300': return FontWeight.w300;
      case 'w400': return FontWeight.w400;
      case 'w500': return FontWeight.w500;
      case 'w600': return FontWeight.w600;
      case 'w700': return FontWeight.w700;
      case 'w800': return FontWeight.w800;
      case 'w900': return FontWeight.w900;
      default: return FontWeight.w500;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColorValue': primaryColorValue,
      'secondaryColorValue': secondaryColorValue,
      'accentColorValue': accentColorValue,
      'backgroundColorValue': backgroundColorValue,
      'surfaceColorValue': surfaceColorValue,
      'cardColorValue': cardColorValue,
      'textPrimaryColorValue': textPrimaryColorValue,
      'textSecondaryColorValue': textSecondaryColorValue,
      'textTertiaryColorValue': textTertiaryColorValue,
      'fontFamily': fontFamily,
      'titleFontSize': titleFontSize,
      'headingFontSize': headingFontSize,
      'bodyFontSize': bodyFontSize,
      'smallFontSize': smallFontSize,
      'titleWeight': _fontWeightToString(titleWeight),
      'headingWeight': _fontWeightToString(headingWeight),
      'bodyWeight': _fontWeightToString(bodyWeight),
      'avatarSize': avatarSize,
      'avatarBorderWidth': avatarBorderWidth,
      'cardRadius': cardRadius,
      'buttonRadius': buttonRadius,
      'spacing': spacing,
      'contentPadding': contentPadding,
      'avatarBorderColorValue': avatarBorderColorValue,
      'avatarGlowEnabled': avatarGlowEnabled,
      'avatarGlowRadius': avatarGlowRadius,
      'avatarGlowOpacity': avatarGlowOpacity,
      'headerGradientEnabled': headerGradientEnabled,
      'headerGradientColors': headerGradientColors,
      'headerGradientBeginX': headerGradientBeginX,
      'headerGradientBeginY': headerGradientBeginY,
      'headerGradientEndX': headerGradientEndX,
      'headerGradientEndY': headerGradientEndY,
      'cardShadowEnabled': cardShadowEnabled,
      'cardShadowBlurRadius': cardShadowBlurRadius,
      'cardShadowSpreadRadius': cardShadowSpreadRadius,
      'cardShadowOffsetX': cardShadowOffsetX,
      'cardShadowOffsetY': cardShadowOffsetY,
      'cardShadowColorValue': cardShadowColorValue,
      'cardShadowOpacity': cardShadowOpacity,
      'avatarShadowEnabled': avatarShadowEnabled,
      'avatarShadowBlurRadius': avatarShadowBlurRadius,
      'avatarShadowSpreadRadius': avatarShadowSpreadRadius,
      'avatarShadowOffsetX': avatarShadowOffsetX,
      'avatarShadowOffsetY': avatarShadowOffsetY,
      'avatarShadowColorValue': avatarShadowColorValue,
      'avatarShadowOpacity': avatarShadowOpacity,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'sectionVisibility': sectionVisibility,
      'sectionOrder': sectionOrder,
      'statsCompactMode': statsCompactMode,
      'statsShowLabels': statsShowLabels,
      'statsShowIcons': statsShowIcons,
      'enableHoverEffects': enableHoverEffects,
      'enablePulseEffects': enablePulseEffects,
    };
  }

  static String _fontWeightToString(FontWeight weight) {
    if (weight == FontWeight.w100) return 'w100';
    if (weight == FontWeight.w200) return 'w200';
    if (weight == FontWeight.w300) return 'w300';
    if (weight == FontWeight.w400) return 'w400';
    if (weight == FontWeight.w500) return 'w500';
    if (weight == FontWeight.w600) return 'w600';
    if (weight == FontWeight.w700) return 'w700';
    if (weight == FontWeight.w800) return 'w800';
    if (weight == FontWeight.w900) return 'w900';
    return 'w500';
  }

  factory ProfileDesign.defaults() {
    return ProfileDesign(
      primaryColorValue: 0xFF00A750,
      secondaryColorValue: 0xFF008C40,
      accentColorValue: 0xFF7ED321,
      backgroundColorValue: 0xFFF8F9FA,
      surfaceColorValue: 0xFFE8F5E9,
      cardColorValue: 0xFFFFFFFF,
      textPrimaryColorValue: 0xFF1A1A1A,
      textSecondaryColorValue: 0xFF666666,
      textTertiaryColorValue: 0xFF999999,
      fontFamily: 'default',
      titleFontSize: 22,
      headingFontSize: 18,
      bodyFontSize: 14,
      smallFontSize: 12,
      titleWeight: FontWeight.w900,
      headingWeight: FontWeight.w700,
      bodyWeight: FontWeight.w500,
      avatarSize: 96,
      avatarBorderWidth: 2,
      cardRadius: 16,
      buttonRadius: 14,
      spacing: 12,
      contentPadding: 16,
      avatarBorderColorValue: 0xFF00A750,
      avatarGlowEnabled: false,
      avatarGlowRadius: 20,
      avatarGlowOpacity: 0.3,
      headerGradientEnabled: false,
      headerGradientColors: [0xFF00A750, 0xFF008C40],
      headerGradientBeginX: 0,
      headerGradientBeginY: 0,
      headerGradientEndX: 1,
      headerGradientEndY: 1,
      cardShadowEnabled: true,
      cardShadowBlurRadius: 8,
      cardShadowSpreadRadius: 0,
      cardShadowOffsetX: 0,
      cardShadowOffsetY: 4,
      cardShadowColorValue: 0xFF000000,
      cardShadowOpacity: 0.05,
      avatarShadowEnabled: true,
      avatarShadowBlurRadius: 8,
      avatarShadowSpreadRadius: 0,
      avatarShadowOffsetX: 0,
      avatarShadowOffsetY: 4,
      avatarShadowColorValue: 0xFF000000,
      avatarShadowOpacity: 0.1,
      blocks: ProfileBlock.defaultBlocks(),
      sectionVisibility: {
        'posts': true, 'reels': true, 'feed': true, 'skills': true, 'team': true,
        'bio': true, 'location': true, 'ai': true, 'header': true, 'stats': true,
        'actions': true, 'switcher': true, 'content': true,
      },
      sectionOrder: {
        'header': 0, 'stats': 1, 'actions': 2, 'team': 3, 'ai': 4,
        'skills': 5, 'bio': 6, 'location': 7, 'switcher': 8, 'content': 9,
      },
      statsCompactMode: false,
      statsShowLabels: true,
      statsShowIcons: true,
      enableHoverEffects: false,
      enablePulseEffects: false,
    );
  }
}

class ProfileBlock {
  final String id;
  final String title;
  final String type;
  final bool enabled;
  final int order;
  final Map<String, dynamic> settings;

  ProfileBlock({
    required this.id,
    required this.title,
    required this.type,
    required this.enabled,
    required this.order,
    this.settings = const {},
  });

  factory ProfileBlock.fromJson(Map<String, dynamic> json) {
  final rawSettings = json['settings'];

  Map<String, dynamic> parsedSettings;
  if (rawSettings is Map) {
    parsedSettings = Map<String, dynamic>.from(rawSettings);
  } else {
    parsedSettings = <String, dynamic>{};
  }

  return ProfileBlock(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    type: (json['type'] ?? 'info').toString(),
    enabled: json['enabled'] == null ? true : json['enabled'] == true,
    order: (json['order'] is num)
        ? (json['order'] as num).toInt()
        : int.tryParse('${json['order']}') ?? 0,
    settings: parsedSettings,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'enabled': enabled,
      'order': order,
      'settings': settings,
    };
  }

  static List<ProfileBlock> defaultBlocks() {
    return [
      ProfileBlock(id: 'posts', title: 'Посты', type: 'grid', enabled: true, order: 0, settings: {}),
      ProfileBlock(id: 'reels', title: 'Reels', type: 'grid', enabled: true, order: 1, settings: {}),
      ProfileBlock(id: 'feed', title: 'Лента', type: 'grid', enabled: true, order: 2, settings: {}),
      ProfileBlock(id: 'skills', title: 'Скиллы', type: 'card', enabled: true, order: 3, settings: {}),
      ProfileBlock(id: 'team', title: 'Команда', type: 'card', enabled: true, order: 4, settings: {}),
      ProfileBlock(id: 'ai', title: 'Спортотека AI', type: 'card', enabled: true, order: 5, settings: {}),
      ProfileBlock(id: 'bio', title: 'О себе', type: 'text', enabled: true, order: 6, settings: {}),
      ProfileBlock(id: 'location', title: 'Локация', type: 'text', enabled: true, order: 7, settings: {}),
    ];
  }

  ProfileBlock copyWith({
    String? id,
    String? title,
    String? type,
    bool? enabled,
    int? order,
    Map<String, dynamic>? settings,
  }) {
    return ProfileBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      settings: settings ?? this.settings,
    );
  }
}

enum _ProfileFeedMode { posts, reels, feed }

class MyProfileScreen extends StatefulWidget {
  final int? userId;

  const MyProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with TickerProviderStateMixin {
  // =============================
  // СТАРЫЕ КОНСТАНТЫ (ОСТАВЛЯЕМ)
  // =============================
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _uploadsBase = 'https://sportotekaapp.ru/uploads';
  static const String _getOrCreatePrivateChatUrl = '$_apiBase/get_or_create_private_chat.php';
  static const String _deletePostUrl = '$_apiBase/delete_post.php';
  static const String _deleteReelUrl = '$_apiBase/delete_reel.php';
  static const String _saveDesignUrl = '$_apiBase/save_profile_design.php';
  static const String _loadDesignUrl = '$_apiBase/get_profile_design.php';

  // =============================
  // НОВЫЕ ПЕРЕМЕННЫЕ ДИЗАЙНА
  // =============================
  ProfileDesign design = ProfileDesign.defaults();
  bool designLoading = false;
  bool designSaving = false;
  late AnimationController _pulseController;
  final Map<String, AnimationController> _hoverControllers = {};

  // =============================
  // СТАРЫЕ ПЕРЕМЕННЫЕ (ВСЕ ОСТАВЛЯЕМ)
  // =============================
  String firstName = "";
  String lastName = "";
  String email = "";
  String role = "";
  String? photo;
  String? bio;
  String? location;
  int? age;
  String? birthDateRaw;
  String? playerTeamName;
  String? playerClubName;
  String? playerTeamLogoUrl;
  List<dynamic> userPosts = [];
  bool isLoadingPosts = false;
  List<Map<String, dynamic>> userReels = [];
  bool isLoadingReels = false;
  List<Map<String, dynamic>> feedPosts = [];
  bool isLoadingFeed = false;
  bool isLoadingProfile = true;
  _ProfileFeedMode _mode = _ProfileFeedMode.posts;
  File? _newPostImage;
  final TextEditingController _newPostText = TextEditingController();
  bool _posting = false;
  bool isFollowing = false;
  bool isOwnProfile = true;
  int followersCount = 0;
  int followingsCount = 0;
  List<_UserShort> _followers = [];
  List<_UserShort> _followings = [];
  bool _loadingFollowers = false;
  bool _loadingFollowings = false;
  static const bool _enableSportotekaAi = false;
  final Random _rnd = Random();
  int _aiCardSeed = 1;
  bool _aiExpanded = false;
  bool _skillsExpanded = false;

  // ========== ВАЖНО: ГЕТТЕР ISPLAYER ==========
  bool get isPlayer => role.trim().toLowerCase() == 'player';

  @override
void initState() {
  super.initState();
  _aiCardSeed = _rnd.nextInt(999999);
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  
  _loadInitialData().then((_) {
    // После загрузки данных принудительно обновляем
    if (mounted) setState(() {});
  });
}
  @override
  void dispose() {
    _newPostText.dispose();
    
    // ===== НОВЫЙ КОД =====
    _pulseController.dispose();
    for (var c in _hoverControllers.values) {
      c.dispose();
    }
    
    super.dispose();
  }

  // =============================
  // СТАРЫЕ МЕТОДЫ (ВСЕ ОСТАВЛЯЕМ)
  // =============================
  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    try {
      final pure = s.contains(' ') ? s.split(' ').first : s;
      return DateTime.tryParse(pure);
    } catch (_) {
      return null;
    }
  }

  int? _calcAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int a = now.year - dob.year;
    final hadBirthdayThisYear = (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) a -= 1;
    if (a < 0 || a > 120) return null;
    return a;
  }

  String? _normalizePhotoUrl(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '$_uploadsBase/$s';
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Пользователь' : name;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  }

  String _safeStr(dynamic v) => (v ?? '').toString();
  int _safeInt(dynamic v) => int.tryParse(_safeStr(v)) ?? 0;

  String _fixUrl(String s) {
    final u = s.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http")) return u;
    return "https://sportotekaapp.ru/$u";
  }

  bool _looksLikeHtml(String s) {
    final t = s.trim().toLowerCase();
    return t.contains('<p') || t.contains('<br') || t.contains('</') || t.contains('<div') || t.contains('<span');
  }

  String _htmlToPlain(String html) {
    var t = html;
    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    t = t.replaceAll('&nbsp;', ' ');
    t = t.replaceAll('&amp;', '&');
    t = t.replaceAll('&quot;', '"');
    t = t.replaceAll('&#39;', "'");
    t = t.replaceAll('&lt;', '<');
    t = t.replaceAll('&gt;', '>');
    return t.trim();
  }

  Future<bool> _confirmDeleteDialog({
    required String title,
    required String message,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _openItemActionsSheet({
    required String title,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Удалить", style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text("Действие нельзя отменить"),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePostById(int postId) async {
    final myId = await PrefUtils.getUserId() ?? 0;
    if (myId <= 0 || postId <= 0) return;

    final ok = await _confirmDeleteDialog(title: "Удалить пост?", message: "Пост будет удалён навсегда.");
    if (!ok) return;

    try {
      final resp = await http.post(
        Uri.parse(_deletePostUrl),
        body: {'user_id': myId.toString(), 'post_id': postId.toString()},
      );

      if (resp.statusCode != 200) {
        Get.snackbar("Ошибка", "Сервер: ${resp.statusCode}", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final data = jsonDecode(resp.body);
      final success = (data is Map) && (data['success'] == true || data['status'] == 'success' || data['status'] == 'deleted');

      if (!success) {
        Get.snackbar("Не удалось удалить", (data is Map && data['error'] != null) ? data['error'].toString() : "Ошибка", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      if (mounted) {
        setState(() {
          userPosts.removeWhere((p) => _toInt((p as Map)['id']) == postId);
          feedPosts.removeWhere((p) => _safeInt(p['id']) == postId);
        });
      }

      await _fetchUserPosts();
      await _fetchAuthorFeedPosts();

      Get.snackbar("Готово", "Пост удалён", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Ошибка сети", e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _deleteReelById(int reelId) async {
    final myId = await PrefUtils.getUserId() ?? 0;
    if (myId <= 0 || reelId <= 0) return;

    final ok = await _confirmDeleteDialog(title: "Удалить Reels?", message: "Видео будет удалено навсегда.");
    if (!ok) return;

    try {
      final resp = await http.post(
        Uri.parse(_deleteReelUrl),
        body: {'user_id': myId.toString(), 'reel_id': reelId.toString()},
      );

      if (resp.statusCode != 200) {
        Get.snackbar("Ошибка", "Сервер: ${resp.statusCode}", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final data = jsonDecode(resp.body);
      final success = (data is Map) && (data['success'] == true || data['status'] == 'success' || data['status'] == 'deleted');

      if (!success) {
        Get.snackbar("Не удалось удалить", (data is Map && data['error'] != null) ? data['error'].toString() : "Ошибка", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      if (mounted) {
        setState(() {
          userReels.removeWhere((r) => _toInt(r['id']) == reelId);
        });
      }

      await _fetchUserReels();

      Get.snackbar("Готово", "Reels удалён", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Ошибка сети", e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        loadUserData(),
        _fetchUserPosts(),
        _fetchUserReels(),
        _fetchAuthorFeedPosts(),
        _checkIfFollowing(),
        _loadFollowersData(),
        // ===== НОВЫЙ КОД =====
        _loadProfileDesign(),
      ]);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  Future<void> loadUserData() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (viewedUserId == null || viewedUserId <= 0) {
      await _loadLocalData();
      return;
    }

    try {
      final uri = Uri.parse('$_apiBase/get_user.php?user_id=$viewedUserId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        if (viewedUserId == currentUserId) {
          await _loadLocalData();
        } else {
          if (mounted) {
            setState(() {
              firstName = 'Пользователь';
              lastName = '';
            });
          }
        }
        return;
      }

      final responseBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(responseBody);

      Map<String, dynamic> root = {};
      if (data is Map) root = data.cast<String, dynamic>();

      Map<String, dynamic> userData = {};
      if (root['success'] == true && root['user'] is Map) {
        userData = (root['user'] as Map).cast<String, dynamic>();
      } else if (root['user'] is Map) {
        userData = (root['user'] as Map).cast<String, dynamic>();
      } else {
        userData = root;
      }

      final first = (userData['first_name'] ?? userData['firstName'] ?? '').toString().trim();
      final last = (userData['last_name'] ?? userData['lastName'] ?? '').toString().trim();
      final mail = (userData['email'] ?? '').toString().trim();
      final r = (userData['role'] ?? '').toString().trim();

      final photo1 = _normalizePhotoUrl(userData['photo_url']);
      final photo2 = _normalizePhotoUrl(userData['photo_urls']);
      final photo3 = _normalizePhotoUrl(userData['photo']);
      final resolvedPhoto = photo1 ?? photo2 ?? photo3;

      final b = (userData['bio'] ?? userData['description'] ?? '').toString().trim();
      final loc = (userData['location'] ?? userData['city'] ?? '').toString().trim();

      int? resolvedAge;
      String? resolvedBirthRaw;
      String? resolvedTeamName;
      String? resolvedClubName;
      String? resolvedTeamLogo;

      final player = (root['player'] is Map) ? (root['player'] as Map).cast<String, dynamic>() : null;
      final playerTeam = (root['player_team'] is Map) ? (root['player_team'] as Map).cast<String, dynamic>() : null;

      if (player != null) {
        final apiAge = _asInt(player['age']);
        final birthAny = player['birth_date'] ?? player['dob'] ?? player['date_of_birth'] ?? player['birthday'];
        final dob = _parseDate(birthAny);
        final computedAge = _calcAge(dob);

        resolvedAge = (apiAge > 0) ? apiAge : computedAge;
        resolvedBirthRaw = (birthAny ?? '').toString().trim();
        if (resolvedBirthRaw != null && resolvedBirthRaw!.isEmpty) {
          resolvedBirthRaw = null;
        }
      }

      if (playerTeam != null) {
        resolvedTeamName = (playerTeam['name'] ?? playerTeam['team_name'] ?? '').toString().trim();
        if (resolvedTeamName.isEmpty) resolvedTeamName = null;

        resolvedClubName = (playerTeam['club_name'] ?? playerTeam['clubName'] ?? '').toString().trim();
        if (resolvedClubName.isEmpty) resolvedClubName = null;

        resolvedTeamLogo = (playerTeam['logo_url'] ?? playerTeam['logoUrl'] ?? '').toString().trim();
        if (resolvedTeamLogo.isEmpty) resolvedTeamLogo = null;
      }

      if (!mounted) return;
      setState(() {
        firstName = first;
        lastName = last;
        email = mail;
        role = r;
        photo = resolvedPhoto;
        bio = b.isEmpty ? null : b;
        location = loc.isEmpty ? null : loc;

        age = resolvedAge;
        birthDateRaw = resolvedBirthRaw;

        playerTeamName = resolvedTeamName;
        playerClubName = resolvedClubName;
        playerTeamLogoUrl = resolvedTeamLogo;
      });

      if (viewedUserId == currentUserId) {
        await PrefUtils.setUserFirstName(firstName);
        await PrefUtils.setUserLastName(lastName);
        await PrefUtils.setUserEmail(email);
        await PrefUtils.setRole(role);

        final photoFile = (userData['photo'] ?? '').toString().trim();
        if (photoFile.isNotEmpty) {
          await PrefUtils.setUserPhoto(photoFile);
        }
      }
    } catch (_) {
      final currentUserId2 = await PrefUtils.getUserId();
      final viewedUserId2 = widget.userId ?? currentUserId2;

      if (viewedUserId2 == currentUserId2) {
        await _loadLocalData();
      } else {
        if (mounted) {
          setState(() {
            firstName = 'Пользователь';
            lastName = '';
          });
        }
      }
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final savedFirstName = await PrefUtils.getUserFirstName();
      final savedLastName = await PrefUtils.getUserLastName();
      final savedEmail = await PrefUtils.getUserEmail();
      final savedRole = await PrefUtils.getRole();
      final savedPhotoFile = await PrefUtils.getUserPhoto();

      if (!mounted) return;
      setState(() {
        firstName = savedFirstName;
        lastName = savedLastName;
        email = savedEmail;
        role = savedRole;
        photo = _normalizePhotoUrl(savedPhotoFile);
      });
    } catch (_) {}
  }

  Future<void> _checkIfFollowing() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (currentUserId == null || currentUserId <= 0) return;

    if (viewedUserId == currentUserId || viewedUserId == null) {
      if (mounted) {
        setState(() {
          isOwnProfile = true;
          isFollowing = false;
        });
      }
      return;
    }

    if (mounted) setState(() => isOwnProfile = false);

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/check_following.php'),
        body: {'follower_id': currentUserId.toString(), 'following_id': viewedUserId.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => isFollowing = (data is Map && data['following'] == true));
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (currentUserId == null || currentUserId <= 0) return;
    if (viewedUserId == null || viewedUserId <= 0) return;

    final url = isFollowing ? '$_apiBase/unsubscribe.php' : '$_apiBase/subscribe.php';

    try {
      final response = await http.post(Uri.parse(url), body: {
        'follower_id': currentUserId.toString(),
        'following_id': viewedUserId.toString(),
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ok = (data is Map) && (data['status'] == 'success' || data['status'] == 'subscribed' || data['status'] == 'unsubscribed' || data['success'] == true);
        if (ok) {
          if (mounted) setState(() => isFollowing = !isFollowing);
          await _loadFollowersData();
          _followers.clear();
          _followings.clear();
        } else {
          Get.snackbar('Ошибка', 'Не удалось изменить подписку', backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        }
      }
    } catch (_) {
      Get.snackbar('Ошибка сети', 'Проверьте соединение', backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openPrivateChat() async {
    try {
      final myId = await PrefUtils.getUserId() ?? 0;
      final peerId = widget.userId ?? 0;

      if (myId <= 0) {
        Get.snackbar("Чат", "Не найден мой user_id", snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (peerId <= 0) {
        Get.snackbar("Чат", "Не найден user_id профиля", snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (myId == peerId) return;

      final resp = await http.post(
        Uri.parse(_getOrCreatePrivateChatUrl),
        body: {'me': myId.toString(), 'peer_id': peerId.toString()},
      );

      if (resp.statusCode != 200) {
        Get.snackbar("Чат", "Ошибка сервера: ${resp.statusCode}", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final data = jsonDecode(resp.body);
      final ok = (data is Map && data['success'] == true);
      if (!ok) {
        Get.snackbar("Чат", (data is Map && data['error'] != null) ? data['error'].toString() : "Ошибка", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final chatId = int.tryParse('${data['chat_id'] ?? ''}') ?? 0;
      if (chatId <= 0) {
        Get.snackbar("Чат", "Не удалось получить chat_id", snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final chatName = fullName.isNotEmpty ? fullName : "Личный чат";

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId, userId: myId, chatName: chatName)),
      );
    } catch (e) {
      Get.snackbar("Чат", "Ошибка: $e", snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _loadFollowersData() async {
    final userId = widget.userId ?? await PrefUtils.getUserId();
    if (userId == null || userId <= 0) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/get_follow_counts.php'),
        body: {'user_id': userId.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final ok = (data is Map) && (data['status'] == 'success' || data['success'] == true);

        if (ok && mounted) {
          setState(() {
            followersCount = _asInt(data['followers']);
            followingsCount = _asInt(data['followings']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserPosts() async {
    if (mounted) setState(() => isLoadingPosts = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) return;

      final response = await http.post(
        Uri.parse('$_apiBase/get_posts_by_user.php'),
        body: jsonEncode({'user_id': userId, 'visibility': 'profile', 'post_type': 'post'}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success') {
          if (mounted) {
            setState(() => userPosts = (data['posts'] is List) ? data['posts'] : []);
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingPosts = false);
    }
  }

  Future<void> _fetchUserReels() async {
    if (mounted) setState(() => isLoadingReels = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) return;

      final url = Uri.parse("$_apiBase/get_reels.php?limit=200&offset=0&user_id=$userId");
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final jsonAny = jsonDecode(body);

      final parsed = _parseReels(jsonAny);
      final filtered = parsed.where((m) => (m['user_id'] ?? 0) == userId).toList();

      if (mounted) setState(() => userReels = filtered);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingReels = false);
    }
  }

  List<Map<String, dynamic>> _parseReels(dynamic jsonAny) {
    List raw;
    if (jsonAny is Map) {
      raw = (jsonAny['reels'] ?? jsonAny['data'] ?? jsonAny['items'] ?? jsonAny['list'] ?? []) as List? ?? [];
    } else if (jsonAny is List) {
      raw = jsonAny;
    } else {
      raw = const [];
    }

    return raw
        .map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);

          final String video = (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '').toString().trim();
          String thumb = (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? '').toString().trim();
          if (thumb.isEmpty && m['preview'] != null) {
            thumb = m['preview'].toString().trim();
          }

          return {
            'id': _toInt(m['id'] ?? m['reel_id'] ?? 0),
            'user_id': _toInt(m['user_id'] ?? m['author_id'] ?? 0),
            'video_url': video,
            'thumbnail': thumb,
            'description': (m['description'] ?? m['caption'] ?? '').toString(),
            'likes': _toInt(m['likes'] ?? m['like_count'] ?? 0),
            'comments': _toInt(m['comments_count'] ?? m['comments'] ?? m['comment_count'] ?? 0),
            'views': _toInt(m['views'] ?? m['view_count'] ?? 0),
            'rotation': m['rotation'],
            'crop_mode': m['crop_mode'],
            'crop_scale': m['crop_scale'],
            'crop_dx': m['crop_dx'],
            'crop_dy': m['crop_dy'],
          };
        })
        .where((e) => (e['video_url'] as String).isNotEmpty)
        .toList();
  }

  Future<void> _fetchAuthorFeedPosts() async {
    if (mounted) setState(() => isLoadingFeed = true);

    try {
      final currentUserId = await PrefUtils.getUserId() ?? 0;
      final authorId = widget.userId ?? currentUserId;

      if (authorId <= 0) return;

      final uri = Uri.parse('$_apiBase/get_posts.php?user_id=$currentUserId');
      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final decoded = json.decode(res.body);

      final List<dynamic> data = decoded is List
          ? decoded
          : (decoded is Map && decoded['posts'] is List) ? (decoded['posts'] as List) : [];

      final filtered = data.where((raw) => _safeInt(raw['user_id']) == authorId).toList();

      final list = filtered.map<Map<String, dynamic>>((raw) {
        final firstName = _safeStr(raw['first_name']);
        final lastName = _safeStr(raw['last_name']);
        final fullName = ('$firstName $lastName').trim();

        final image = _fixUrl(_safeStr(raw['image']));
        final avatar = _fixUrl(_safeStr(raw['photo'] ?? raw['photo_url'] ?? raw['avatar']));

        final rawBody = _safeStr(raw['body']);
        final plainBody = _looksLikeHtml(rawBody) ? _htmlToPlain(rawBody) : rawBody;

        return <String, dynamic>{
          'id': _safeInt(raw['id']),
          'title': _safeStr(raw['title']),
          'text': plainBody,
          'imageUrl': image,
          'date': DateTime.tryParse(_safeStr(raw['created_at'])) ?? DateTime.now(),
          'authorName': fullName.isNotEmpty ? fullName : (_safeStr(raw['author_name']).isNotEmpty ? _safeStr(raw['author_name']) : 'Пользователь'),
          'user_id': _safeInt(raw['user_id']),
          'authorAvatar': avatar,
          'likes': _safeInt(raw['likes_count']),
          'comments': _safeInt(raw['comments_count']),
        };
      }).toList();

      if (!mounted) return;
      setState(() => feedPosts = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingFeed = false);
    }
  }

  void _openFeedPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          title: _safeStr(post['title']).isNotEmpty ? _safeStr(post['title']) : 'Пост',
          body: _safeStr(post['text']),
          newsId: _safeInt(post['id']),
          imageUrl: _safeStr(post['imageUrl']),
        ),
      ),
    ).then((_) => _fetchAuthorFeedPosts());
  }

  Future<void> _submitProfilePost() async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId <= 0) return;

    final text = _newPostText.text.trim();
    if (text.isEmpty && _newPostImage == null) {
      Get.snackbar("Публикация", "Напишите текст или добавьте фото", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (mounted) setState(() => _posting = true);

    final uri = Uri.parse('$_apiBase/insert_post.php');
    final req = http.MultipartRequest('POST', uri)
      ..fields['title'] = ''
      ..fields['body'] = text
      ..fields['category'] = ''
      ..fields['team'] = ''
      ..fields['author'] = ''
      ..fields['user_id'] = userId.toString()
      ..fields['visibility'] = 'profile'
      ..fields['post_type'] = 'post';

    if (_newPostImage != null) {
      req.files.add(await http.MultipartFile.fromPath('image', _newPostImage!.path));
    }

    try {
      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        if (mounted) Navigator.pop(context);

        if (mounted) {
          setState(() {
            _newPostText.clear();
            _newPostImage = null;
          });
        }

        await _fetchUserPosts();
        await _fetchAuthorFeedPosts();
      } else {
        Get.snackbar("Ошибка", "Не удалось опубликовать: $body", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Ошибка сети", e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Новая публикация", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: const Text("Профиль"),
                        avatar: const Icon(Icons.person, size: 18),
                        backgroundColor: ProfilePalette.primaryGreen.withOpacity(0.10),
                        side: BorderSide(color: ProfilePalette.primaryGreen.withOpacity(0.25)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPostText,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Что нового?",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  if (_newPostImage != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_newPostImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setModalState(() => _newPostImage = null),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            setModalState(() => _newPostImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        color: ProfilePalette.primaryGreen,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _posting ? null : _submitProfilePost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfilePalette.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _posting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Опубликовать"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openUploadReels() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UploadReelScreen(onUploadComplete: () async {
        await _fetchUserReels();
      })),
    );
    await _fetchUserReels();
  }

  Future<void> _uploadProfilePhoto(File imageFile) async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId <= 0) return;

    final uri = Uri.parse('$_apiBase/upload_user_photo.php');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = userId.toString()
        ..files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

      final response = await request.send();
      if (response.statusCode != 200) return;

      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      if (data is Map && data['status'] == 'success') {
        final serverPhotoUrl = (data['photo_url'] ?? '').toString().trim();
        final fileName = (data['file_name'] ?? '').toString().trim();

        final newUrl = serverPhotoUrl.isNotEmpty ? _normalizePhotoUrl(serverPhotoUrl) : _normalizePhotoUrl(fileName);

        if (mounted) setState(() => photo = newUrl);

        if (fileName.isNotEmpty) {
          await PrefUtils.setUserPhoto(fileName);
        }

        await loadUserData();
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _uploadProfilePhoto(File(picked.path));
    }
  }

  Future<void> _fetchFollowersList() async {
    if (_loadingFollowers) return;
    if (mounted) setState(() => _loadingFollowers = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) {
        _followers = [];
        return;
      }

      final res = await http.post(
        Uri.parse('$_apiBase/get_followers.php'),
        body: {'user_id': userId.toString()},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['users'] is List) {
          _followers = (data['users'] as List).map((e) => _UserShort.fromJson(e)).toList();
        } else {
          _followers = [];
        }
      }
    } catch (_) {
      _followers = [];
    } finally {
      if (mounted) setState(() => _loadingFollowers = false);
    }
  }

  Future<void> _fetchFollowingsList() async {
    if (_loadingFollowings) return;
    if (mounted) setState(() => _loadingFollowings = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) {
        _followings = [];
        return;
      }

      final res = await http.post(
        Uri.parse('$_apiBase/get_followings.php'),
        body: {'user_id': userId.toString()},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['users'] is List) {
          _followings = (data['users'] as List).map((e) => _UserShort.fromJson(e)).toList();
        } else {
          _followings = [];
        }
      }
    } catch (_) {
      _followings = [];
    } finally {
      if (mounted) setState(() => _loadingFollowings = false);
    }
  }

  void _openUsersModal({required bool showFollowers}) async {
    if (showFollowers) {
      await _fetchFollowersList();
    } else {
      await _fetchFollowingsList();
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final title = showFollowers ? 'Подписчики' : 'Подписки';
        final loading = showFollowers ? _loadingFollowers : _loadingFollowings;
        final items = showFollowers ? _followers : _followings;

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), color: Colors.white),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 24, color: Colors.black)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: ProfilePalette.primaryGreen)))
              else if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(showFollowers ? Icons.people_outline : Icons.person_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(showFollowers ? 'Пока нет подписчиков' : 'Пока нет подписок', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = items[index];
                      final hasPhoto = (u.photoUrl ?? '').trim().isNotEmpty;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: ProfilePalette.primaryGreen.withOpacity(0.1),
                          backgroundImage: hasPhoto ? NetworkImage(u.photoUrl!) : null,
                          child: !hasPhoto
                              ? Text(
                                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'П',
                                  style: const TextStyle(color: ProfilePalette.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16),
                                )
                              : null,
                        ),
                        title: Text(u.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
                        subtitle: u.role?.isNotEmpty == true ? Text(u.role!, style: const TextStyle(fontSize: 14, color: Colors.grey)) : null,
                        trailing: (u.id != null)
                            ? OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MyProfileScreen(userId: u.id)),
                                  ).then((_) {
                                    _loadFollowersData();
                                    _checkIfFollowing();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ProfilePalette.primaryGreen,
                                  side: const BorderSide(color: ProfilePalette.primaryGreen),
                                ),
                                child: const Text('Посмотреть'),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onEditProfile() {
    Get.snackbar("Профиль", "Редактирование профиля подключим следующим шагом.", snackPosition: SnackPosition.BOTTOM);
  }

  void _openAiDetailsSheet({
    required String title,
    required String subtitle,
    required List<_AiBullet> bullets,
    String? primaryActionLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.55))),
                ),
                const SizedBox(height: 14),
                ...bullets.map((b) => _AiBulletTile(bullet: b)).toList(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.black.withOpacity(0.12)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Закрыть", style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (primaryActionLabel != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Get.snackbar(
                              "Спортотека AI",
                              "Подключим этот модуль на сервере следующим шагом 🙂",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: ProfilePalette.primaryGreen.withOpacity(0.12),
                              colorText: Colors.black,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfilePalette.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(primaryActionLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================
  // НОВЫЕ МЕТОДЫ ДЛЯ ДИЗАЙНА
  // =============================
  Future<void> _loadProfileDesign() async {
  final userId = widget.userId ?? await PrefUtils.getUserId();
  if (userId == null || userId <= 0) return;

  if (mounted) {
    setState(() => designLoading = true);
  }

  try {
    final uri = Uri.parse('$_loadDesignUrl?user_id=$userId');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    debugPrint('GET DESIGN STATUS: ${response.statusCode}');
    debugPrint('GET DESIGN BODY: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode != 200) return;

    final body = utf8.decode(response.bodyBytes);
    final data = jsonDecode(body);

    if (data is Map && data['success'] == true && data['design'] != null) {
      final loadedDesign = ProfileDesign.fromJson(
        Map<String, dynamic>.from(data['design']),
      );

      if (mounted) {
        setState(() {
          design = loadedDesign;
        });
      }
    }
  } catch (e) {
    debugPrint('Error loading design: $e');
  } finally {
    if (mounted) {
      setState(() => designLoading = false);
    }
  }
}
  Future<void> _saveProfileDesign() async {
  final userId = await PrefUtils.getUserId();
  if (userId == null || userId <= 0) return;

  if (mounted) {
    setState(() => designSaving = true);
  }

  try {
    final designJson = jsonEncode(design.toJson());

    debugPrint('SAVE DESIGN USER ID: $userId');
    debugPrint('SAVE DESIGN JSON: $designJson');

    final response = await http.post(
      Uri.parse(_saveDesignUrl),
      body: {
        'user_id': userId.toString(),
        'design_json': designJson,
      },
    ).timeout(const Duration(seconds: 15));

    final body = utf8.decode(response.bodyBytes);
    debugPrint('SAVE DESIGN STATUS: ${response.statusCode}');
    debugPrint('SAVE DESIGN BODY: $body');

    if (response.statusCode != 200) {
      Get.snackbar(
        'Ошибка',
        'Сервер вернул ${response.statusCode}',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final data = jsonDecode(body);

    if (data is Map && data['success'] == true) {
      Get.snackbar(
        'Успешно',
        'Дизайн профиля сохранён',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: design.primaryColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'Ошибка',
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Не удалось сохранить дизайн',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  } catch (e) {
    Get.snackbar(
      'Ошибка',
      'Не удалось сохранить дизайн: $e',
      snackPosition: SnackPosition.BOTTOM,
    );
  } finally {
    if (mounted) {
      setState(() => designSaving = false);
    }
  }
}
  void _openDesignEditor() {
    if (!isOwnProfile) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DesignEditorModal(
        initialDesign: design,
        onSave: (newDesign) async {
          setState(() => design = newDesign);
          await _saveProfileDesign();
        },
      ),
    );
  }

  // =============================
  // СТИЛИ ТЕКСТА
  // =============================
  TextStyle get _titleStyle => TextStyle(
    fontFamily: design.fontFamily != 'default' ? design.fontFamily : null,
    fontSize: design.titleFontSize,
    fontWeight: design.titleWeight,
    color: design.textPrimaryColor,
    height: 1.2,
  );

  TextStyle get _headingStyle => TextStyle(
    fontFamily: design.fontFamily != 'default' ? design.fontFamily : null,
    fontSize: design.headingFontSize,
    fontWeight: design.headingWeight,
    color: design.textPrimaryColor,
    height: 1.3,
  );

  TextStyle get _bodyStyle => TextStyle(
    fontFamily: design.fontFamily != 'default' ? design.fontFamily : null,
    fontSize: design.bodyFontSize,
    fontWeight: design.bodyWeight,
    color: design.textSecondaryColor,
    height: 1.4,
  );

  TextStyle get _smallStyle => TextStyle(
    fontFamily: design.fontFamily != 'default' ? design.fontFamily : null,
    fontSize: design.smallFontSize,
    fontWeight: design.bodyWeight,
    color: design.textTertiaryColor,
    height: 1.2,
  );

  // =============================
  // BUILD МЕТОД (ОБНОВЛЕННЫЙ)
  // =============================
  @override
  Widget build(BuildContext context) {
    final hasAvatar = (photo ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: design.backgroundColor,
      appBar: AppBar(
        backgroundColor: design.cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Row(
          children: [
            if (widget.userId != null)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: design.textPrimaryColor),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle,
              ),
            ),
          ],
        ),
        actions: [
          if (isOwnProfile) ...[
            IconButton(
              icon: Icon(
                Icons.palette_rounded,
                color: design.primaryColor,
              ),
              onPressed: _openDesignEditor,
              tooltip: 'Настроить дизайн',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.add, color: design.textPrimaryColor),
              onSelected: (v) {
                if (v == 'post') _openCreatePostModal();
                if (v == 'reel') _openUploadReels();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'post', child: Text("Новый пост")),
                PopupMenuItem(value: 'reel', child: Text("Новый Reels")),
              ],
            ),
          ],
        ],
      ),
      body: isLoadingProfile
          ? Center(child: CircularProgressIndicator(color: design.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: design.primaryColor,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(design.contentPadding),
                      child: _buildProfileContent(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // =============================
  // НОВЫЕ МЕТОДЫ ПОСТРОЕНИЯ UI
  // =============================
  Widget _buildProfileContent() {
    final sortedBlocks = design.blocks
        .where((b) => b.enabled)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (design.sectionVisibility['header'] != false)
          _buildHeaderSection(),
        SizedBox(height: design.spacing),
        if (design.sectionVisibility['stats'] != false)
          _buildStatsSection(),
        SizedBox(height: design.spacing),
        if (design.sectionVisibility['actions'] != false && !isOwnProfile)
          _buildActionsSection(),
        SizedBox(height: design.spacing),
        ...sortedBlocks.map((block) {
          return Padding(
            padding: EdgeInsets.only(bottom: design.spacing),
            child: _buildBlock(block),
          );
        }).toList(),
        if (design.sectionVisibility['switcher'] != false)
          _buildModeSwitcher(),
        SizedBox(height: design.spacing),
        if (design.sectionVisibility['content'] != false)
          _buildContentGrid(),
      ],
    );
  }

  Widget _buildHeaderSection() {
    final hasAvatar = (photo ?? '').trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(design.contentPadding),
      decoration: BoxDecoration(
        gradient: design.headerGradientEnabled ? LinearGradient(
          begin: Alignment(design.headerGradientBeginX, design.headerGradientBeginY),
          end: Alignment(design.headerGradientEndX, design.headerGradientEndY),
          colors: design.headerGradientColors.map((c) => Color(c)).toList(),
        ) : null,
        color: design.headerGradientEnabled ? null : design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Row(
        children: [
          _buildAvatar(hasAvatar),
          SizedBox(width: design.spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName, style: _titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (isPlayer) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: design.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Игрок', style: _smallStyle.copyWith(color: design.primaryColor, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          if (age != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: design.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, size: 14, color: design.accentColor),
                  const SizedBox(width: 4),
                  Text('$age лет', style: _smallStyle.copyWith(color: design.accentColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool hasAvatar) {
    return GestureDetector(
      onTap: isOwnProfile ? _pickAndUploadPhoto : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: design.avatarSize,
            height: design.avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: design.avatarBorderColor, width: design.avatarBorderWidth),
              boxShadow: design.avatarShadowEnabled ? [BoxShadow(
                color: Color(design.avatarShadowColorValue).withOpacity(design.avatarShadowOpacity),
                blurRadius: design.avatarShadowBlurRadius,
                spreadRadius: design.avatarShadowSpreadRadius,
                offset: Offset(design.avatarShadowOffsetX, design.avatarShadowOffsetY),
              )] : null,
            ),
            child: ClipOval(
              child: hasAvatar
                  ? Image.network(photo!, width: design.avatarSize, height: design.avatarSize, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar())
                  : _buildDefaultAvatar(),
            ),
          ),
          if (design.avatarGlowEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: design.primaryColor.withOpacity(design.avatarGlowOpacity * _pulseController.value),
                            blurRadius: design.avatarGlowRadius,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (isOwnProfile)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: design.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(design.contentPadding),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(count: userPosts.length, label: design.statsShowLabels ? 'Посты' : null, icon: design.statsShowIcons ? Icons.grid_on_rounded : null),
          _buildStatItem(count: userReels.length, label: design.statsShowLabels ? 'Reels' : null, icon: design.statsShowIcons ? Icons.play_circle_fill_rounded : null),
          GestureDetector(
            onTap: () => _openUsersModal(showFollowers: false),
            child: _buildStatItem(count: followingsCount, label: design.statsShowLabels ? 'Подписки' : null, icon: design.statsShowIcons ? Icons.person_add_rounded : null),
          ),
          GestureDetector(
            onTap: () => _openUsersModal(showFollowers: true),
            child: _buildStatItem(count: followersCount, label: design.statsShowLabels ? 'Подписчики' : null, icon: design.statsShowIcons ? Icons.people_rounded : null),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required int count, String? label, IconData? icon}) {
    if (design.statsCompactMode) {
      return Column(
        children: [
          if (icon != null) Icon(icon, size: 20, color: design.textSecondaryColor),
          const SizedBox(height: 4),
          Text(count.toString(), style: _headingStyle.copyWith(color: design.textPrimaryColor)),
        ],
      );
    }

    return Column(
      children: [
        Text(count.toString(), style: _headingStyle.copyWith(fontSize: design.headingFontSize * 1.2, color: design.primaryColor)),
        const SizedBox(height: 4),
        if (label != null) Text(label, style: _smallStyle),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Row(
      children: [
        Expanded(child: _buildActionButton(
          label: isFollowing ? 'Отписаться' : 'Подписаться',
          icon: isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
          onTap: _toggleFollow,
          primary: !isFollowing,
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildActionButton(
          label: 'Написать',
          icon: Icons.chat_rounded,
          onTap: _openPrivateChat,
          primary: false,
        )),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onTap, bool primary = true}) {
    final button = ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: design.bodyFontSize)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? design.primaryColor : design.cardColor,
        foregroundColor: primary ? Colors.white : design.textPrimaryColor,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(design.buttonRadius),
          side: primary ? BorderSide.none : BorderSide(color: design.textTertiaryColor),
        ),
      ),
    );

    if (design.enableHoverEffects) {
      return _HoverAnimation(child: button);
    }

    return button;
  }

  Widget _buildBlock(ProfileBlock block) {
    switch (block.id) {
      case 'team':
        return _buildTeamCard();
      case 'ai':
  if (!isPlayer || !_enableSportotekaAi) return const SizedBox();
  return _buildAiSection();
      case 'skills':
        if (!isPlayer) return const SizedBox();
        return _buildSkillsSection();
      case 'bio':
        if (bio?.isEmpty != false) return const SizedBox();
        return _buildBioSection();
      case 'location':
        if (location?.isEmpty != false) return const SizedBox();
        return _buildLocationSection();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTeamCard() {
    final logo = (playerTeamLogoUrl ?? '').trim();
    final team = (playerTeamName ?? '').trim();
    final club = (playerClubName ?? '').trim();

    if (team.isEmpty && club.isEmpty) return const SizedBox();

    return Container(
      padding: EdgeInsets.all(design.contentPadding),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: design.primaryColor.withOpacity(0.08),
              border: Border.all(color: design.primaryColor.withOpacity(0.18)),
            ),
            child: ClipOval(
              child: logo.isNotEmpty
                  ? Image.network(logo, fit: BoxFit.cover)
                  : Icon(Icons.shield_outlined, color: design.primaryColor, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.isNotEmpty ? team : "Команда", style: _headingStyle),
                const SizedBox(height: 4),
                Text(club.isNotEmpty ? "Клуб: $club" : "Клуб: —", style: _bodyStyle),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: design.primaryColor, borderRadius: BorderRadius.circular(12)),
            child: Text("Профи", style: _smallStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
  // ===== НОВЫЙ КОД =====
  if (!_enableSportotekaAi) return const SizedBox();
  
  return _buildExpandableCard(
    title: "Спортотека AI",
    icon: Icons.auto_awesome_rounded,
    expanded: _aiExpanded,
    onToggle: () => setState(() => _aiExpanded = !_aiExpanded),
    badge: const Text("BETA"),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text("Персонально для: $fullName", style: _smallStyle.copyWith(color: design.textSecondaryColor, fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => setState(() => _aiCardSeed = _rnd.nextInt(999999)), icon: Icon(Icons.refresh_rounded, color: design.textSecondaryColor)),
          ],
        ),
        const SizedBox(height: 10),
        _AiMatchIqCard(seed: _aiCardSeed, playerName: fullName, position: "ST", design: design),
        const SizedBox(height: 10),
        _AiTrainingScanCard(seed: _aiCardSeed, design: design),
        const SizedBox(height: 10),
        _AiWeeklyChallengeCard(seed: _aiCardSeed, design: design),
      ],
    ),
  );
}

  Widget _buildSkillsSection() {
    return _buildExpandableCard(
      title: "Скиллы игрока",
      icon: Icons.shield_outlined,
      expanded: _skillsExpanded,
      onToggle: () => setState(() => _skillsExpanded = !_skillsExpanded),
      subtitle: "Автоматически рассчитываются на основе тренировок",
      child: PlayerSkillsFifaStub(
        playerName: fullName,
        position: "ST",
        clubName: (playerClubName ?? "Sportoteka").toString(),
        photoUrl: photo,
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required bool expanded,
    required VoidCallback onToggle,
    String? subtitle,
    Widget? badge,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(design.cardRadius),
            child: Padding(
              padding: EdgeInsets.all(design.contentPadding),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: design.primaryColor.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: design.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(title, style: _headingStyle)),
                            if (badge != null) badge,
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle, style: _smallStyle, maxLines: 2),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: design.textSecondaryColor),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(design.contentPadding, 0, design.contentPadding, design.contentPadding),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: EdgeInsets.all(design.contentPadding),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: design.primaryColor),
              const SizedBox(width: 8),
              Text('О себе', style: _headingStyle),
            ],
          ),
          const SizedBox(height: 8),
          Text(bio!, style: _bodyStyle),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: EdgeInsets.all(design.contentPadding),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, size: 18, color: design.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(location!, style: _bodyStyle)),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: design.textTertiaryColor.withOpacity(0.2)),
        boxShadow: design.cardShadowEnabled ? [BoxShadow(
          color: Color(design.cardShadowColorValue).withOpacity(design.cardShadowOpacity),
          blurRadius: design.cardShadowBlurRadius,
          spreadRadius: design.cardShadowSpreadRadius,
          offset: Offset(design.cardShadowOffsetX, design.cardShadowOffsetY),
        )] : null,
      ),
      child: Row(
        children: [
          _buildModeButton(
            active: _mode == _ProfileFeedMode.posts,
            icon: Icons.grid_on_rounded,
            label: "Посты",
            onTap: () => setState(() => _mode = _ProfileFeedMode.posts),
          ),
          _buildModeButton(
            active: _mode == _ProfileFeedMode.reels,
            icon: Icons.play_circle_fill_rounded,
            label: "Reels",
            onTap: () => setState(() => _mode = _ProfileFeedMode.reels),
          ),
          _buildModeButton(
            active: _mode == _ProfileFeedMode.feed,
            icon: Icons.public,
            label: "Лента",
            onTap: () => setState(() => _mode = _ProfileFeedMode.feed),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({required bool active, required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? design.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : design.textSecondaryColor),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: active ? Colors.white : design.textSecondaryColor, fontSize: design.smallFontSize)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentGrid() {
    if (_mode == _ProfileFeedMode.posts) {
      return _buildPostsGrid();
    } else if (_mode == _ProfileFeedMode.reels) {
      return _buildReelsGrid();
    } else {
      return _buildFeedGrid();
    }
  }

  Widget _buildPostsGrid() {
    if (isLoadingPosts) {
      return Center(child: CircularProgressIndicator(color: design.primaryColor));
    }

    if (userPosts.isEmpty) {
      return _buildEmptyState(icon: Icons.add_photo_alternate_outlined, message: 'Пока нет постов');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: userPosts.length,
      itemBuilder: (context, index) {
        final post = userPosts[index] as Map<String, dynamic>;
        final imageUrl = (post['image'] ?? '').toString().trim();
        final hasImage = imageUrl.isNotEmpty;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsDetailScreen(
                  title: (post['category'] ?? 'Мой пост').toString(),
                  body: (post['body'] ?? '').toString(),
                  newsId: int.tryParse(post['id'].toString()) ?? 0,
                  imageUrl: imageUrl,
                ),
              ),
            );
          },
          child: Container(
            color: design.surfaceColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.network(imageUrl, fit: BoxFit.cover)
                else
                  Container(
                    color: design.surfaceColor,
                    child: Center(child: Icon(Icons.article_outlined, size: 40, color: design.textTertiaryColor)),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.30), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.50), borderRadius: BorderRadius.circular(6)),
                    child: Icon(hasImage ? Icons.photo : Icons.article, size: 16, color: Colors.white),
                  ),
                ),
                if (isOwnProfile)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildDeleteMenuButton(onTap: () {
                      final postId = _toInt(post['id']);
                      _openItemActionsSheet(title: "Пост", onDelete: () => _deletePostById(postId));
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    if (isLoadingReels) {
      return Center(child: CircularProgressIndicator(color: design.primaryColor));
    }

    if (userReels.isEmpty) {
      return _buildEmptyState(icon: Icons.play_circle_outline, message: 'Пока нет Reels');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: userReels.length,
      itemBuilder: (context, index) {
        final reel = userReels[index];

        return GestureDetector(
          onTap: () async {
            final viewedUserId = widget.userId ?? await PrefUtils.getUserId() ?? 0;
            if (!mounted || viewedUserId <= 0) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserReelsScreen(
                  userId: viewedUserId,
                  initialIndex: index,
                  title: "Reels: $fullName",
                ),
              ),
            ).then((_) => _fetchUserReels());
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlayerProfileReelWidget(
                videoUrl: reel['video_url'] ?? '',
                thumbnailUrl: reel['thumbnail'] ?? '',
                autoPlay: false,
                muted: true,
                rotationDeg: reel['rotation'] as int?,
                cropMode: reel['crop_mode'] as String?,
                cropScale: (reel['crop_scale'] as num?)?.toDouble(),
                cropDx: (reel['crop_dx'] as num?)?.toDouble(),
                cropDy: (reel['crop_dy'] as num?)?.toDouble(),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.25), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                ),
              ),
              if (isOwnProfile)
                Positioned(
                  left: 8,
                  top: 8,
                  child: _buildDeleteMenuButton(onTap: () {
                    final reelId = _toInt(reel['id']);
                    _openItemActionsSheet(title: "Reels", onDelete: () => _deleteReelById(reelId));
                  }),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Row(
                  children: [
                    _buildMiniBadge("❤ ${reel['likes'] ?? 0}"),
                    const SizedBox(width: 6),
                    _buildMiniBadge("💬 ${reel['comments'] ?? 0}"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedGrid() {
    if (isLoadingFeed) {
      return Center(child: CircularProgressIndicator(color: design.primaryColor));
    }

    if (feedPosts.isEmpty) {
      return _buildEmptyState(icon: Icons.public, message: 'В ленте пока нет постов');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: feedPosts.length,
      itemBuilder: (context, index) {
        final post = feedPosts[index];
        final img = _safeStr(post['imageUrl']).trim();
        final hasImage = img.isNotEmpty;

        return GestureDetector(
          onTap: () => _openFeedPostDetail(post),
          child: Container(
            color: design.surfaceColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.network(img, fit: BoxFit.cover)
                else
                  Container(
                    color: design.surfaceColor,
                    child: Center(child: Icon(Icons.public, size: 40, color: design.textTertiaryColor)),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.30), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.50), borderRadius: BorderRadius.circular(6)),
                    child: Icon(hasImage ? Icons.photo : Icons.public, size: 16, color: Colors.white),
                  ),
                ),
                if (isOwnProfile)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildDeleteMenuButton(onTap: () {
                      final postId = _safeInt(post['id']);
                      _openItemActionsSheet(title: "Пост в ленте", onDelete: () => _deletePostById(postId));
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteMenuButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.50), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.more_horiz, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: design.textTertiaryColor),
          const SizedBox(height: 16),
          Text(message, style: _bodyStyle.copyWith(color: design.textSecondaryColor)),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: design.surfaceColor,
      child: Center(child: Icon(Icons.person, size: design.avatarSize * 0.5, color: design.primaryColor)),
    );
  }
}

// =============================
// ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ (ОСТАВЛЯЕМ)
// =============================
class _UserShort {
  final int? id;
  final String fullName;
  final String? role;
  final String? photoUrl;

  _UserShort({this.id, required this.fullName, this.role, this.photoUrl});

  factory _UserShort.fromJson(dynamic json) {
    final m = (json as Map).cast<String, dynamic>();

    final first = (m['first_name'] ?? '').toString().trim();
    final last = (m['last_name'] ?? '').toString().trim();

    String? normalize(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      return 'https://sportotekaapp.ru/uploads/$s';
    }

    final photo = normalize(m['photo_url']) ?? normalize(m['photo']);

    final name = '$first $last'.trim();
    return _UserShort(
      id: (m['id'] is int) ? m['id'] as int : int.tryParse(m['id']?.toString() ?? ''),
      fullName: name.isEmpty ? 'Пользователь' : name,
      role: (m['role'] ?? '').toString(),
      photoUrl: photo,
    );
  }
}

class _AiBullet {
  final IconData icon;
  final String title;
  final String text;
  const _AiBullet({required this.icon, required this.title, required this.text});
}

class _AiBulletTile extends StatelessWidget {
  final _AiBullet bullet;
  const _AiBulletTile({required this.bullet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProfilePalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ProfilePalette.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ProfilePalette.primaryGreen.withOpacity(0.22)),
            ),
            child: Icon(bullet.icon, color: ProfilePalette.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bullet.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.black)),
                const SizedBox(height: 4),
                Text(bullet.text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.62), height: 1.15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMatchIqCard extends StatelessWidget {
  final int seed;
  final String playerName;
  final String position;
  final ProfileDesign design;

  const _AiMatchIqCard({required this.seed, required this.playerName, required this.position, required this.design});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        border: Border.all(color: design.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: design.primaryColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.psychology_alt_rounded, color: design.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Match IQ • Совет на сегодня", style: TextStyle(fontSize: design.bodyFontSize, fontWeight: FontWeight.w900, color: design.textPrimaryColor)),
                    const SizedBox(height: 2),
                    Text("Персонально для позиции: $position", style: TextStyle(fontSize: design.smallFontSize, color: design.textSecondaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("Играй в 2 касания и чаще открывайся в полуфланг.", style: TextStyle(fontSize: design.bodyFontSize, color: design.textPrimaryColor)),
        ],
      ),
    );
  }
}

class _AiTrainingScanCard extends StatefulWidget {
  final int seed;
  final ProfileDesign design;

  const _AiTrainingScanCard({required this.seed, required this.design});

  @override
  State<_AiTrainingScanCard> createState() => _AiTrainingScanCardState();
}

class _AiTrainingScanCardState extends State<_AiTrainingScanCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final p = _progress.value;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.design.cardColor,
            borderRadius: BorderRadius.circular(widget.design.cardRadius),
            border: Border.all(color: widget.design.primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: widget.design.primaryColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.auto_awesome_rounded, color: widget.design.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("AI-анализ тренировки", style: TextStyle(fontSize: widget.design.bodyFontSize, fontWeight: FontWeight.w900, color: widget.design.textPrimaryColor)),
                        const SizedBox(height: 2),
                        Text(
                          p < 0.999 ? "Сканируем упражнения… ${(p * 100).clamp(0, 100).toInt()}%" : "Готово • Отчёт сформирован",
                          style: TextStyle(fontSize: widget.design.smallFontSize, color: widget.design.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: p.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: widget.design.surfaceColor,
                  valueColor: AlwaysStoppedAnimation(widget.design.primaryColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiWeeklyChallengeCard extends StatelessWidget {
  final int seed;
  final ProfileDesign design;

  const _AiWeeklyChallengeCard({required this.seed, required this.design});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: BorderRadius.circular(design.cardRadius),
        border: Border.all(color: design.accentColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: design.accentColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.emoji_events_rounded, color: design.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Челлендж недели", style: TextStyle(fontSize: design.bodyFontSize, fontWeight: FontWeight.w900, color: design.textPrimaryColor)),
                const SizedBox(height: 4),
                Text("20 точных передач", style: TextStyle(fontSize: design.smallFontSize, color: design.accentColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverAnimation extends StatefulWidget {
  final Widget child;

  const _HoverAnimation({required this.child});

  @override
  State<_HoverAnimation> createState() => _HoverAnimationState();
}

class _HoverAnimationState extends State<_HoverAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: 1.0 + (_controller.value * 0.05), child: child);
        },
        child: widget.child,
      ),
    );
  }
}

class _DesignEditorModal extends StatefulWidget {
  final ProfileDesign initialDesign;
  final Function(ProfileDesign) onSave;

  const _DesignEditorModal({required this.initialDesign, required this.onSave});

  @override
  State<_DesignEditorModal> createState() => _DesignEditorModalState();
}

class _DesignEditorModalState extends State<_DesignEditorModal> {
  late ProfileDesign design;
  int _selectedTab = 0;
  
  

  final List<Color> colorPresets = [
  // Яркие спортивные
  const Color(0xFF00A750),
  const Color(0xFF008C40),
  const Color(0xFF2563EB),
  const Color(0xFF1D4ED8),
  const Color(0xFF7C3AED),
  const Color(0xFF9333EA),
  const Color(0xFFDC2626),
  const Color(0xFFEF4444),
  const Color(0xFFF59E0B),
  const Color(0xFFEAB308),

  // Мягкие пастельные
  const Color(0xFFB8E1DD),
  const Color(0xFFC7D2FE),
  const Color(0xFFD8B4FE),
  const Color(0xFFFBCFE8),
  const Color(0xFFFDE68A),
  const Color(0xFFBFDBFE),
  const Color(0xFFA7F3D0),
  const Color(0xFFF5D0FE),
  const Color(0xFFFFE4E6),
  const Color(0xFFE2E8F0),

  // Премиум тёмные
  const Color(0xFF0F172A),
  const Color(0xFF1E293B),
  const Color(0xFF334155),
  const Color(0xFF475569),
  const Color(0xFF64748B),
  const Color(0xFF94A3B8),

  // Светлые фоны
  const Color(0xFFF8F9FA),
  const Color(0xFFF1F5F9),
  const Color(0xFFFAFAF9),
  const Color(0xFFFDF2F8),
  const Color(0xFFECFDF5),
  const Color(0xFFEFF6FF),
  const Color(0xFFFFFFFF),
];
  final List<String> fontFamilies = ['default', 'inter', 'montserrat', 'roboto', 'poppins'];

  @override
  void initState() {
    super.initState();
    design = widget.initialDesign;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: design.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text('Настройка профиля', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: design.textPrimaryColor))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
  height: 50,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: ListView(
    scrollDirection: Axis.horizontal,
    children: [
      _buildTab('Цвета', 0),
      _buildTab('Текст', 1),
      _buildTab('Размеры', 2),
      _buildTab('Тени', 3),
      _buildTab('Блоки', 4),
    ],
  ),
),

Container(
  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: design.backgroundColor,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.grey.shade200),
  ),
  child: _buildLivePreview(),
),

const Divider(height: 1),

Expanded(
  child: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_selectedTab == 0) _buildColorsTab(),
      if (_selectedTab == 1) _buildTextTab(),
      if (_selectedTab == 2) _buildSizesTab(),
      if (_selectedTab == 3) _buildShadowsTab(),
      if (_selectedTab == 4) _buildBlocksTab(),
    ],
  ),
),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => design = ProfileDesign.defaults()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(design);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: design.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildLivePreview() {
  return Container(
    padding: EdgeInsets.all(design.contentPadding),
    decoration: BoxDecoration(
      color: design.cardColor,
      borderRadius: BorderRadius.circular(design.cardRadius),
      boxShadow: design.cardShadowEnabled
          ? [
              BoxShadow(
                color: Color(design.cardShadowColorValue)
                    .withOpacity(design.cardShadowOpacity),
                blurRadius: design.cardShadowBlurRadius,
                spreadRadius: design.cardShadowSpreadRadius,
                offset: Offset(
                  design.cardShadowOffsetX,
                  design.cardShadowOffsetY,
                ),
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: design.avatarSize * 0.55,
              height: design.avatarSize * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: design.surfaceColor,
                border: Border.all(
                  color: Color(design.avatarBorderColorValue),
                  width: design.avatarBorderWidth,
                ),
                boxShadow: design.avatarShadowEnabled
                    ? [
                        BoxShadow(
                          color: Color(design.avatarShadowColorValue)
                              .withOpacity(design.avatarShadowOpacity),
                          blurRadius: design.avatarShadowBlurRadius,
                          spreadRadius: design.avatarShadowSpreadRadius,
                          offset: Offset(
                            design.avatarShadowOffsetX,
                            design.avatarShadowOffsetY,
                          ),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.person,
                color: design.primaryColor,
                size: design.avatarSize * 0.25,
              ),
            ),
            SizedBox(width: design.spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Спортотека',
                    style: TextStyle(
                      fontSize: design.titleFontSize,
                      fontWeight: design.titleWeight,
                      color: design.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Игрок • Центральный полузащитник',
                    style: TextStyle(
                      fontSize: design.smallFontSize,
                      fontWeight: design.bodyWeight,
                      color: design.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: design.spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _previewStat('24', 'Посты'),
            _previewStat('8', 'Reels'),
            _previewStat('153', 'Подписчики'),
          ],
        ),
        SizedBox(height: design.spacing),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(design.contentPadding),
          decoration: BoxDecoration(
            color: design.surfaceColor,
            borderRadius: BorderRadius.circular(design.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'О себе',
                style: TextStyle(
                  fontSize: design.headingFontSize,
                  fontWeight: design.headingWeight,
                  color: design.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Футболист, тренируюсь каждый день и развиваю свой профиль в Спортотеке.',
                style: TextStyle(
                  fontSize: design.bodyFontSize,
                  fontWeight: design.bodyWeight,
                  color: design.textSecondaryColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _previewStat(String value, String label) {
  if (design.statsCompactMode) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: design.headingFontSize,
            fontWeight: design.headingWeight,
            color: design.primaryColor,
          ),
        ),
      ],
    );
  }

  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: design.headingFontSize,
          fontWeight: design.headingWeight,
          color: design.primaryColor,
        ),
      ),
      const SizedBox(height: 4),
      if (design.statsShowLabels)
        Text(
          label,
          style: TextStyle(
            fontSize: design.smallFontSize,
            color: design.textSecondaryColor,
          ),
        ),
    ],
  );
}
  Widget _buildTab(String label, int index) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? design.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? design.primaryColor : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: active ? design.primaryColor : design.textSecondaryColor, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildColorsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorSection('Основной цвет', design.primaryColorValue, (c) => setState(() => design = design.copyWith(primaryColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Второй цвет', design.secondaryColorValue, (c) => setState(() => design = design.copyWith(secondaryColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Акцентный цвет', design.accentColorValue, (c) => setState(() => design = design.copyWith(accentColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Фон', design.backgroundColorValue, (c) => setState(() => design = design.copyWith(backgroundColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Карточки', design.cardColorValue, (c) => setState(() => design = design.copyWith(cardColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Текст основной', design.textPrimaryColorValue, (c) => setState(() => design = design.copyWith(textPrimaryColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Текст второстепенный', design.textSecondaryColorValue, (c) => setState(() => design = design.copyWith(textSecondaryColorValue: c.value))),
        const SizedBox(height: 16),
        _buildColorSection('Граница аватара', design.avatarBorderColorValue, (c) => setState(() => design = design.copyWith(avatarBorderColorValue: c.value))),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Градиент в шапке'),
          value: design.headerGradientEnabled,
          onChanged: (v) => setState(() => design = design.copyWith(headerGradientEnabled: v)),
        ),
        if (design.headerGradientEnabled) ...[
          const SizedBox(height: 8),
          const Text('Цвета градиента:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(design.headerGradientColors.length, (i) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(design.headerGradientColors[i]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildColorSection(String label, int value, Function(Color) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: colorPresets.map((preset) {
            final active = preset.value == value;
            return GestureDetector(
              onTap: () => onChanged(preset),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preset,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? Colors.black : Colors.transparent, width: 2),
                ),
                child: active ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

 Widget _buildTextTab() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        value: design.fontFamily,
        decoration: const InputDecoration(
          labelText: 'Шрифт',
          border: OutlineInputBorder(),
        ),
        items: fontFamilies
            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            design = design.copyWith(fontFamily: v);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Заголовок',
        value: design.titleFontSize,
        min: 16,
        max: 32,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(titleFontSize: v);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Подзаголовок',
        value: design.headingFontSize,
        min: 14,
        max: 24,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(headingFontSize: v);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Основной текст',
        value: design.bodyFontSize,
        min: 12,
        max: 18,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(bodyFontSize: v);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Мелкий текст',
        value: design.smallFontSize,
        min: 10,
        max: 14,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(smallFontSize: v);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildWeightSelector(
        label: 'Жирность заголовка',
        value: design.titleWeight,
        onChanged: (w) {
          setState(() {
            design = design.copyWith(titleWeight: w);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildWeightSelector(
        label: 'Жирность подзаголовка',
        value: design.headingWeight,
        onChanged: (w) {
          setState(() {
            design = design.copyWith(headingWeight: w);
          });
        },
      ),
      const SizedBox(height: 16),
      _buildWeightSelector(
        label: 'Жирность текста',
        value: design.bodyWeight,
        onChanged: (w) {
          setState(() {
            design = design.copyWith(bodyWeight: w);
          });
        },
      ),
    ],
  );
}

  Widget _buildSizesTab() {
  return Column(
    children: [
      _buildSliderTile(
        label: 'Размер аватара',
        value: design.avatarSize,
        min: 60,
        max: 120,
        onChanged: (v) => setState(() {
          design = design.copyWith(avatarSize: v);
        }),
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Толщина рамки аватара',
        value: design.avatarBorderWidth,
        min: 1,
        max: 5,
        onChanged: (v) => setState(() {
          design = design.copyWith(avatarBorderWidth: v);
        }),
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Скругление карточек',
        value: design.cardRadius,
        min: 8,
        max: 32,
        onChanged: (v) => setState(() {
          design = design.copyWith(cardRadius: v);
        }),
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Скругление кнопок',
        value: design.buttonRadius,
        min: 4,
        max: 24,
        onChanged: (v) => setState(() {
          design = design.copyWith(buttonRadius: v);
        }),
      ),
      const SizedBox(height: 16),
      _buildSliderTile(
        label: 'Отступы',
        value: design.spacing,
        min: 8,
        max: 24,
        onChanged: (v) => setState(() {
          design = design.copyWith(spacing: v);
        }),
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Компактная статистика'),
        value: design.statsCompactMode,
        onChanged: (v) => setState(() {
          design = design.copyWith(statsCompactMode: v);
        }),
      ),
      SwitchListTile(
        title: const Text('Показывать подписи в статистике'),
        value: design.statsShowLabels,
        onChanged: (v) => setState(() {
          design = design.copyWith(statsShowLabels: v);
        }),
      ),
      SwitchListTile(
        title: const Text('Показывать иконки в статистике'),
        value: design.statsShowIcons,
        onChanged: (v) => setState(() {
          design = design.copyWith(statsShowIcons: v);
        }),
      ),
    ],
  );
}

 Widget _buildShadowsTab() {
  return Column(
    children: [
      SwitchListTile(
        title: const Text('Тень карточек'),
        value: design.cardShadowEnabled,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(cardShadowEnabled: v);
          });
        },
      ),
      if (design.cardShadowEnabled) ...[
        const SizedBox(height: 16),
        _buildSliderTile(
          label: 'Размытие',
          value: design.cardShadowBlurRadius,
          min: 0,
          max: 20,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(cardShadowBlurRadius: v);
            });
          },
        ),
        _buildSliderTile(
          label: 'Смещение по X',
          value: design.cardShadowOffsetX,
          min: -10,
          max: 10,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(cardShadowOffsetX: v);
            });
          },
        ),
        _buildSliderTile(
          label: 'Смещение по Y',
          value: design.cardShadowOffsetY,
          min: -10,
          max: 10,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(cardShadowOffsetY: v);
            });
          },
        ),
        _buildSliderTile(
          label: 'Прозрачность',
          value: design.cardShadowOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(cardShadowOpacity: v);
            });
          },
        ),
      ],
      const Divider(height: 32),
      SwitchListTile(
        title: const Text('Тень аватара'),
        value: design.avatarShadowEnabled,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(avatarShadowEnabled: v);
          });
        },
      ),
      if (design.avatarShadowEnabled) ...[
        const SizedBox(height: 16),
        _buildSliderTile(
          label: 'Размытие',
          value: design.avatarShadowBlurRadius,
          min: 0,
          max: 20,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(avatarShadowBlurRadius: v);
            });
          },
        ),
        _buildSliderTile(
          label: 'Прозрачность',
          value: design.avatarShadowOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(avatarShadowOpacity: v);
            });
          },
        ),
      ],
      const Divider(height: 32),
      SwitchListTile(
        title: const Text('Свечение аватара'),
        value: design.avatarGlowEnabled,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(avatarGlowEnabled: v);
          });
        },
      ),
      if (design.avatarGlowEnabled) ...[
        const SizedBox(height: 16),
        _buildSliderTile(
          label: 'Радиус свечения',
          value: design.avatarGlowRadius,
          min: 0,
          max: 40,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(avatarGlowRadius: v);
            });
          },
        ),
        _buildSliderTile(
          label: 'Интенсивность',
          value: design.avatarGlowOpacity,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) {
            setState(() {
              design = design.copyWith(avatarGlowOpacity: v);
            });
          },
        ),
      ],
    ],
  );
}

  Widget _buildBlocksTab() {
  return Column(
    children: [
      ...design.blocks.map((block) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: design.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.drag_handle_rounded, color: design.textTertiaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.title,
                  style: TextStyle(
                    fontWeight:
                        block.enabled ? FontWeight.w700 : FontWeight.normal,
                    color: block.enabled
                        ? design.textPrimaryColor
                        : design.textTertiaryColor,
                  ),
                ),
              ),
              Switch(
                value: block.enabled,
                onChanged: (v) {
                  setState(() {
                    final newBlocks = design.blocks.map((b) {
                      if (b.id == block.id) {
                        return b.copyWith(enabled: v);
                      }
                      return b;
                    }).toList();

                    design = design.copyWith(blocks: newBlocks);
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Показывать шапку'),
        value: design.sectionVisibility['header'] ?? true,
        onChanged: (v) {
          setState(() {
            final newVisibility = Map<String, bool>.from(design.sectionVisibility);
            newVisibility['header'] = v;
            design = design.copyWith(sectionVisibility: newVisibility);
          });
        },
      ),
      SwitchListTile(
        title: const Text('Показывать статистику'),
        value: design.sectionVisibility['stats'] ?? true,
        onChanged: (v) {
          setState(() {
            final newVisibility = Map<String, bool>.from(design.sectionVisibility);
            newVisibility['stats'] = v;
            design = design.copyWith(sectionVisibility: newVisibility);
          });
        },
      ),
      SwitchListTile(
        title: const Text('Показывать кнопки действий'),
        value: design.sectionVisibility['actions'] ?? true,
        onChanged: (v) {
          setState(() {
            final newVisibility = Map<String, bool>.from(design.sectionVisibility);
            newVisibility['actions'] = v;
            design = design.copyWith(sectionVisibility: newVisibility);
          });
        },
      ),
      SwitchListTile(
        title: const Text('Показывать переключатель'),
        value: design.sectionVisibility['switcher'] ?? true,
        onChanged: (v) {
          setState(() {
            final newVisibility = Map<String, bool>.from(design.sectionVisibility);
            newVisibility['switcher'] = v;
            design = design.copyWith(sectionVisibility: newVisibility);
          });
        },
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Эффекты при наведении'),
        value: design.enableHoverEffects,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(enableHoverEffects: v);
          });
        },
      ),
      SwitchListTile(
        title: const Text('Пульсирующие эффекты'),
        value: design.enablePulseEffects,
        onChanged: (v) {
          setState(() {
            design = design.copyWith(enablePulseEffects: v);
          });
        },
      ),
    ],
  );
}

  Widget _buildSliderTile({required String label, required double value, required double min, required double max, int? divisions, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(value: value, min: min, max: max, divisions: divisions, activeColor: design.primaryColor, onChanged: onChanged),
      ],
    );
  }

  Widget _buildWeightSelector({required String label, required FontWeight value, required ValueChanged<FontWeight> onChanged}) {
    final weights = [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: weights.map((w) {
            final active = w == value;
            return FilterChip(
              label: Text(w.value.toString()),
              selected: active,
              onSelected: (_) => onChanged(w),
              selectedColor: design.primaryColor.withOpacity(0.2),
            );
          }).toList(),
        ),
      ],
    );
  }
}