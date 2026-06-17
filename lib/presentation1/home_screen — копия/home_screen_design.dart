import 'dart:convert';
import 'package:flutter/material.dart';

enum HomeSectionType {
  ringBanner,
  reels,
  promo,
  innovations,
  events,
  venues,
  clubs,
  tickets,
  posts,
}

enum HomeFontPreset {
  inter,
  roboto,
  montserrat,
  system,
}

enum HomeHeaderStyle {
  gradient,
  glass,
  solid,
  premium,
}

enum HomeCardStyle {
  soft,
  glass,
  outlined,
  elevated,
}

enum HomeSectionLayout {
  horizontal,
  grid,
  compactList,
  hero,
}

class HomeSectionConfig {
  final HomeSectionType type;
  final bool visible;
  final bool pinned;
  final HomeSectionLayout layout;
  final int itemLimit;
  final double cardWidth;
  final double cardHeight;
  final bool showSubtitle;
  final bool showIcon;
  final Color? accentOverride;

  const HomeSectionConfig({
    required this.type,
    this.visible = true,
    this.pinned = false,
    this.layout = HomeSectionLayout.horizontal,
    this.itemLimit = 6,
    this.cardWidth = 300,
    this.cardHeight = 224,
    this.showSubtitle = true,
    this.showIcon = true,
    this.accentOverride,
  });

  HomeSectionConfig copyWith({
    HomeSectionType? type,
    bool? visible,
    bool? pinned,
    HomeSectionLayout? layout,
    int? itemLimit,
    double? cardWidth,
    double? cardHeight,
    bool? showSubtitle,
    bool? showIcon,
    Color? accentOverride,
    bool clearAccentOverride = false,
  }) {
    return HomeSectionConfig(
      type: type ?? this.type,
      visible: visible ?? this.visible,
      pinned: pinned ?? this.pinned,
      layout: layout ?? this.layout,
      itemLimit: itemLimit ?? this.itemLimit,
      cardWidth: cardWidth ?? this.cardWidth,
      cardHeight: cardHeight ?? this.cardHeight,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      showIcon: showIcon ?? this.showIcon,
      accentOverride: clearAccentOverride
          ? null
          : (accentOverride ?? this.accentOverride),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'visible': visible,
      'pinned': pinned,
      'layout': layout.name,
      'itemLimit': itemLimit,
      'cardWidth': cardWidth,
      'cardHeight': cardHeight,
      'showSubtitle': showSubtitle,
      'showIcon': showIcon,
      'accentOverride': accentOverride?.value,
    };
  }

  factory HomeSectionConfig.fromJson(Map<String, dynamic> json) {
    return HomeSectionConfig(
      type: HomeSectionType.values.firstWhere(
        (e) => e.name == (json['type'] ?? HomeSectionType.reels.name),
        orElse: () => HomeSectionType.reels,
      ),
      visible: json['visible'] ?? true,
      pinned: json['pinned'] ?? false,
      layout: HomeSectionLayout.values.firstWhere(
        (e) => e.name == (json['layout'] ?? HomeSectionLayout.horizontal.name),
        orElse: () => HomeSectionLayout.horizontal,
      ),
      itemLimit: (json['itemLimit'] ?? 6) as int,
      cardWidth: (json['cardWidth'] ?? 300).toDouble(),
      cardHeight: (json['cardHeight'] ?? 224).toDouble(),
      showSubtitle: json['showSubtitle'] ?? true,
      showIcon: json['showIcon'] ?? true,
      accentOverride: json['accentOverride'] == null
          ? null
          : Color(json['accentOverride']),
    );
  }
}

class HomeScreenDesign {
  final String presetName;

  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color borderColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color headerStartColor;
  final Color headerMidColor;
  final Color headerEndColor;
  final Color textColor;
  final Color mutedTextColor;

  final HomeFontPreset fontPreset;
  final HomeHeaderStyle headerStyle;
  final HomeCardStyle cardStyle;

  final double pageHorizontalPadding;
  final double pageTopSpacing;
  final double sectionGap;

  final double cardRadius;
  final double smallRadius;
  final double bannerRadius;
  final double borderWidth;

  final double shadowOpacity;
  final double shadowBlur;
  final double blurSigma;
  final double glassOpacity;

  final double headerExpandedHeight;
  final double headerCollapsedExtraHeight;
  final double quickActionIconSize;
  final double quickActionBubbleSize;
  final double quickActionScale;
  final double quickActionsCornerRadius;

  final double headerTitleSize;
  final double headerSubtitleSize;
  final double sectionTitleSize;
  final double sectionSubtitleSize;
  final double cardTitleSize;
  final double bodyTextSize;
  final double smallTextSize;

  final bool glassEnabled;
  final bool useFloatingCards;
  final bool useGradientCards;
  final bool useRoundedBanners;
  final bool compactMode;
  final bool denseMode;
  final bool showHeaderSubtitle;
  final bool showQuickActionsLabels;
  final bool showPromoBanner;
  final bool showSectionBackgrounds;
  final bool showSectionIcons;
  final bool premiumGlow;

  final String customHeaderTitle;
  final String customHeaderSubtitle;

  final List<HomeSectionConfig> sections;

  const HomeScreenDesign({
    required this.presetName,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.borderColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.headerStartColor,
    required this.headerMidColor,
    required this.headerEndColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.fontPreset,
    required this.headerStyle,
    required this.cardStyle,
    required this.pageHorizontalPadding,
    required this.pageTopSpacing,
    required this.sectionGap,
    required this.cardRadius,
    required this.smallRadius,
    required this.bannerRadius,
    required this.borderWidth,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.blurSigma,
    required this.glassOpacity,
    required this.headerExpandedHeight,
    required this.headerCollapsedExtraHeight,
    required this.quickActionIconSize,
    required this.quickActionBubbleSize,
    required this.quickActionScale,
    required this.quickActionsCornerRadius,
    required this.headerTitleSize,
    required this.headerSubtitleSize,
    required this.sectionTitleSize,
    required this.sectionSubtitleSize,
    required this.cardTitleSize,
    required this.bodyTextSize,
    required this.smallTextSize,
    required this.glassEnabled,
    required this.useFloatingCards,
    required this.useGradientCards,
    required this.useRoundedBanners,
    required this.compactMode,
    required this.denseMode,
    required this.showHeaderSubtitle,
    required this.showQuickActionsLabels,
    required this.showPromoBanner,
    required this.showSectionBackgrounds,
    required this.showSectionIcons,
    required this.premiumGlow,
    required this.customHeaderTitle,
    required this.customHeaderSubtitle,
    required this.sections,
  });

  factory HomeScreenDesign.defaults() {
    return HomeScreenDesign(
      presetName: 'Sportoteka Classic',
      backgroundColor: const Color(0xFFEFF8F1),
      surfaceColor: Colors.white,
      cardColor: Colors.white,
      borderColor: const Color(0xFFE3ECE6),
      primaryColor: const Color(0xFF00A750),
      secondaryColor: const Color(0xFF7ED321),
      headerStartColor: const Color(0xFF0B5E36),
      headerMidColor: const Color(0xFF00A750),
      headerEndColor: const Color(0xFF00C060),
      textColor: const Color(0xFF18201B),
      mutedTextColor: const Color(0xFF64706A),
      fontPreset: HomeFontPreset.inter,
      headerStyle: HomeHeaderStyle.gradient,
      cardStyle: HomeCardStyle.soft,
      pageHorizontalPadding: 20,
      pageTopSpacing: 16,
      sectionGap: 24,
      cardRadius: 22,
      smallRadius: 14,
      bannerRadius: 24,
      borderWidth: 1,
      shadowOpacity: 0.08,
      shadowBlur: 18,
      blurSigma: 14,
      glassOpacity: 0.16,
      headerExpandedHeight: 360,
      headerCollapsedExtraHeight: 16,
      quickActionIconSize: 24,
      quickActionBubbleSize: 56,
      quickActionScale: 1.0,
      quickActionsCornerRadius: 24,
      headerTitleSize: 28,
      headerSubtitleSize: 14,
      sectionTitleSize: 18,
      sectionSubtitleSize: 13,
      cardTitleSize: 16,
      bodyTextSize: 14,
      smallTextSize: 12,
      glassEnabled: false,
      useFloatingCards: false,
      useGradientCards: false,
      useRoundedBanners: true,
      compactMode: false,
      denseMode: false,
      showHeaderSubtitle: true,
      showQuickActionsLabels: true,
      showPromoBanner: true,
      showSectionBackgrounds: false,
      showSectionIcons: true,
      premiumGlow: false,
      customHeaderTitle: 'Спортотека Футбол',
      customHeaderSubtitle: 'Вместе к победам!',
      sections: const [
        HomeSectionConfig(type: HomeSectionType.ringBanner),
        HomeSectionConfig(type: HomeSectionType.reels),
        HomeSectionConfig(type: HomeSectionType.promo),
        HomeSectionConfig(type: HomeSectionType.innovations),
        HomeSectionConfig(type: HomeSectionType.events),
        HomeSectionConfig(type: HomeSectionType.venues),
        HomeSectionConfig(type: HomeSectionType.clubs),
        HomeSectionConfig(type: HomeSectionType.tickets),
        HomeSectionConfig(type: HomeSectionType.posts),
      ],
    );
  }

  factory HomeScreenDesign.glassMint() {
    return HomeScreenDesign.defaults().copyWith(
      presetName: 'Glass Mint',
      backgroundColor: const Color(0xFFF4FFFA),
      primaryColor: const Color(0xFF00B56A),
      secondaryColor: const Color(0xFF9BEA7A),
      headerStartColor: const Color(0xFF0A3D2B),
      headerMidColor: const Color(0xFF00A86B),
      headerEndColor: const Color(0xFF58D68D),
      glassEnabled: true,
      headerStyle: HomeHeaderStyle.glass,
      cardStyle: HomeCardStyle.glass,
      blurSigma: 0,
      glassOpacity: 0.0,
      shadowOpacity: 0.10,
      premiumGlow: true,
      useFloatingCards: true,
      cardRadius: 26,
      bannerRadius: 28,
    );
  }

  factory HomeScreenDesign.darkArena() {
    return HomeScreenDesign.defaults().copyWith(
      presetName: 'Dark Arena',
      backgroundColor: const Color(0xFF0F1512),
      surfaceColor: const Color(0xFF141D18),
      cardColor: const Color(0xFF17221C),
      borderColor: const Color(0xFF233128),
      textColor: Colors.white,
      mutedTextColor: const Color(0xFFB0BBB4),
      primaryColor: const Color(0xFF00C96B),
      secondaryColor: const Color(0xFF9EFF6A),
      headerStartColor: const Color(0xFF09150F),
      headerMidColor: const Color(0xFF0D3A25),
      headerEndColor: const Color(0xFF00A750),
      headerStyle: HomeHeaderStyle.premium,
      cardStyle: HomeCardStyle.elevated,
      premiumGlow: true,
      shadowOpacity: 0.18,
      shadowBlur: 30,
      glassEnabled: false,
      useGradientCards: true,
      useFloatingCards: true,
    );
  }

  factory HomeScreenDesign.whitePremium() {
    return HomeScreenDesign.defaults().copyWith(
      presetName: 'White Premium',
      backgroundColor: const Color(0xFFF9FAFB),
      surfaceColor: Colors.white,
      cardColor: Colors.white,
      borderColor: const Color(0xFFE8ECF0),
      primaryColor: const Color(0xFF009F4D),
      secondaryColor: const Color(0xFF65D887),
      headerStartColor: const Color(0xFFECFFF4),
      headerMidColor: const Color(0xFFDFF8E7),
      headerEndColor: const Color(0xFFC9F0D8),
      textColor: const Color(0xFF141A16),
      mutedTextColor: const Color(0xFF758078),
      headerStyle: HomeHeaderStyle.solid,
      cardStyle: HomeCardStyle.outlined,
      glassEnabled: false,
      premiumGlow: false,
      shadowOpacity: 0.06,
      shadowBlur: 14,
      bannerRadius: 30,
      cardRadius: 24,
    );
  }

  HomeScreenDesign copyWith({
    String? presetName,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? cardColor,
    Color? borderColor,
    Color? primaryColor,
    Color? secondaryColor,
    Color? headerStartColor,
    Color? headerMidColor,
    Color? headerEndColor,
    Color? textColor,
    Color? mutedTextColor,
    HomeFontPreset? fontPreset,
    HomeHeaderStyle? headerStyle,
    HomeCardStyle? cardStyle,
    double? pageHorizontalPadding,
    double? pageTopSpacing,
    double? sectionGap,
    double? cardRadius,
    double? smallRadius,
    double? bannerRadius,
    double? borderWidth,
    double? shadowOpacity,
    double? shadowBlur,
    double? blurSigma,
    double? glassOpacity,
    double? headerExpandedHeight,
    double? headerCollapsedExtraHeight,
    double? quickActionIconSize,
    double? quickActionBubbleSize,
    double? quickActionScale,
    double? quickActionsCornerRadius,
    double? headerTitleSize,
    double? headerSubtitleSize,
    double? sectionTitleSize,
    double? sectionSubtitleSize,
    double? cardTitleSize,
    double? bodyTextSize,
    double? smallTextSize,
    bool? glassEnabled,
    bool? useFloatingCards,
    bool? useGradientCards,
    bool? useRoundedBanners,
    bool? compactMode,
    bool? denseMode,
    bool? showHeaderSubtitle,
    bool? showQuickActionsLabels,
    bool? showPromoBanner,
    bool? showSectionBackgrounds,
    bool? showSectionIcons,
    bool? premiumGlow,
    String? customHeaderTitle,
    String? customHeaderSubtitle,
    List<HomeSectionConfig>? sections,
  }) {
    return HomeScreenDesign(
      presetName: presetName ?? this.presetName,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      cardColor: cardColor ?? this.cardColor,
      borderColor: borderColor ?? this.borderColor,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      headerStartColor: headerStartColor ?? this.headerStartColor,
      headerMidColor: headerMidColor ?? this.headerMidColor,
      headerEndColor: headerEndColor ?? this.headerEndColor,
      textColor: textColor ?? this.textColor,
      mutedTextColor: mutedTextColor ?? this.mutedTextColor,
      fontPreset: fontPreset ?? this.fontPreset,
      headerStyle: headerStyle ?? this.headerStyle,
      cardStyle: cardStyle ?? this.cardStyle,
      pageHorizontalPadding:
          pageHorizontalPadding ?? this.pageHorizontalPadding,
      pageTopSpacing: pageTopSpacing ?? this.pageTopSpacing,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      smallRadius: smallRadius ?? this.smallRadius,
      bannerRadius: bannerRadius ?? this.bannerRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      blurSigma: blurSigma ?? this.blurSigma,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      headerExpandedHeight:
          headerExpandedHeight ?? this.headerExpandedHeight,
      headerCollapsedExtraHeight:
          headerCollapsedExtraHeight ?? this.headerCollapsedExtraHeight,
      quickActionIconSize:
          quickActionIconSize ?? this.quickActionIconSize,
      quickActionBubbleSize:
          quickActionBubbleSize ?? this.quickActionBubbleSize,
      quickActionScale: quickActionScale ?? this.quickActionScale,
      quickActionsCornerRadius:
          quickActionsCornerRadius ?? this.quickActionsCornerRadius,
      headerTitleSize: headerTitleSize ?? this.headerTitleSize,
      headerSubtitleSize:
          headerSubtitleSize ?? this.headerSubtitleSize,
      sectionTitleSize: sectionTitleSize ?? this.sectionTitleSize,
      sectionSubtitleSize:
          sectionSubtitleSize ?? this.sectionSubtitleSize,
      cardTitleSize: cardTitleSize ?? this.cardTitleSize,
      bodyTextSize: bodyTextSize ?? this.bodyTextSize,
      smallTextSize: smallTextSize ?? this.smallTextSize,
      glassEnabled: glassEnabled ?? this.glassEnabled,
      useFloatingCards: useFloatingCards ?? this.useFloatingCards,
      useGradientCards: useGradientCards ?? this.useGradientCards,
      useRoundedBanners: useRoundedBanners ?? this.useRoundedBanners,
      compactMode: compactMode ?? this.compactMode,
      denseMode: denseMode ?? this.denseMode,
      showHeaderSubtitle:
          showHeaderSubtitle ?? this.showHeaderSubtitle,
      showQuickActionsLabels:
          showQuickActionsLabels ?? this.showQuickActionsLabels,
      showPromoBanner: showPromoBanner ?? this.showPromoBanner,
      showSectionBackgrounds:
          showSectionBackgrounds ?? this.showSectionBackgrounds,
      showSectionIcons: showSectionIcons ?? this.showSectionIcons,
      premiumGlow: premiumGlow ?? this.premiumGlow,
      customHeaderTitle: customHeaderTitle ?? this.customHeaderTitle,
      customHeaderSubtitle:
          customHeaderSubtitle ?? this.customHeaderSubtitle,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'presetName': presetName,
      'backgroundColor': backgroundColor.value,
      'surfaceColor': surfaceColor.value,
      'cardColor': cardColor.value,
      'borderColor': borderColor.value,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'headerStartColor': headerStartColor.value,
      'headerMidColor': headerMidColor.value,
      'headerEndColor': headerEndColor.value,
      'textColor': textColor.value,
      'mutedTextColor': mutedTextColor.value,
      'fontPreset': fontPreset.name,
      'headerStyle': headerStyle.name,
      'cardStyle': cardStyle.name,
      'pageHorizontalPadding': pageHorizontalPadding,
      'pageTopSpacing': pageTopSpacing,
      'sectionGap': sectionGap,
      'cardRadius': cardRadius,
      'smallRadius': smallRadius,
      'bannerRadius': bannerRadius,
      'borderWidth': borderWidth,
      'shadowOpacity': shadowOpacity,
      'shadowBlur': shadowBlur,
      'blurSigma': blurSigma,
      'glassOpacity': glassOpacity,
      'headerExpandedHeight': headerExpandedHeight,
      'headerCollapsedExtraHeight': headerCollapsedExtraHeight,
      'quickActionIconSize': quickActionIconSize,
      'quickActionBubbleSize': quickActionBubbleSize,
      'quickActionScale': quickActionScale,
      'quickActionsCornerRadius': quickActionsCornerRadius,
      'headerTitleSize': headerTitleSize,
      'headerSubtitleSize': headerSubtitleSize,
      'sectionTitleSize': sectionTitleSize,
      'sectionSubtitleSize': sectionSubtitleSize,
      'cardTitleSize': cardTitleSize,
      'bodyTextSize': bodyTextSize,
      'smallTextSize': smallTextSize,
      'glassEnabled': glassEnabled,
      'useFloatingCards': useFloatingCards,
      'useGradientCards': useGradientCards,
      'useRoundedBanners': useRoundedBanners,
      'compactMode': compactMode,
      'denseMode': denseMode,
      'showHeaderSubtitle': showHeaderSubtitle,
      'showQuickActionsLabels': showQuickActionsLabels,
      'showPromoBanner': showPromoBanner,
      'showSectionBackgrounds': showSectionBackgrounds,
      'showSectionIcons': showSectionIcons,
      'premiumGlow': premiumGlow,
      'customHeaderTitle': customHeaderTitle,
      'customHeaderSubtitle': customHeaderSubtitle,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }

  factory HomeScreenDesign.fromJson(Map<String, dynamic> json) {
    return HomeScreenDesign(
      presetName: (json['presetName'] ?? 'Custom').toString(),
      backgroundColor: Color(json['backgroundColor'] ?? 0xFFEFF8F1),
      surfaceColor: Color(json['surfaceColor'] ?? 0xFFFFFFFF),
      cardColor: Color(json['cardColor'] ?? 0xFFFFFFFF),
      borderColor: Color(json['borderColor'] ?? 0xFFE3ECE6),
      primaryColor: Color(json['primaryColor'] ?? 0xFF00A750),
      secondaryColor: Color(json['secondaryColor'] ?? 0xFF7ED321),
      headerStartColor: Color(json['headerStartColor'] ?? 0xFF0B5E36),
      headerMidColor: Color(json['headerMidColor'] ?? 0xFF00A750),
      headerEndColor: Color(json['headerEndColor'] ?? 0xFF00C060),
      textColor: Color(json['textColor'] ?? 0xFF18201B),
      mutedTextColor: Color(json['mutedTextColor'] ?? 0xFF64706A),
      fontPreset: HomeFontPreset.values.firstWhere(
        (e) => e.name == (json['fontPreset'] ?? HomeFontPreset.inter.name),
        orElse: () => HomeFontPreset.inter,
      ),
      headerStyle: HomeHeaderStyle.values.firstWhere(
        (e) => e.name == (json['headerStyle'] ?? HomeHeaderStyle.gradient.name),
        orElse: () => HomeHeaderStyle.gradient,
      ),
      cardStyle: HomeCardStyle.values.firstWhere(
        (e) => e.name == (json['cardStyle'] ?? HomeCardStyle.soft.name),
        orElse: () => HomeCardStyle.soft,
      ),
      pageHorizontalPadding:
          (json['pageHorizontalPadding'] ?? 20).toDouble(),
      pageTopSpacing: (json['pageTopSpacing'] ?? 16).toDouble(),
      sectionGap: (json['sectionGap'] ?? 24).toDouble(),
      cardRadius: (json['cardRadius'] ?? 22).toDouble(),
      smallRadius: (json['smallRadius'] ?? 14).toDouble(),
      bannerRadius: (json['bannerRadius'] ?? 24).toDouble(),
      borderWidth: (json['borderWidth'] ?? 1).toDouble(),
      shadowOpacity: (json['shadowOpacity'] ?? 0.08).toDouble(),
      shadowBlur: (json['shadowBlur'] ?? 18).toDouble(),
      blurSigma: (json['blurSigma'] ?? 14).toDouble(),
      glassOpacity: (json['glassOpacity'] ?? 0.16).toDouble(),
      headerExpandedHeight:
          (json['headerExpandedHeight'] ?? 360).toDouble(),
      headerCollapsedExtraHeight:
          (json['headerCollapsedExtraHeight'] ?? 16).toDouble(),
      quickActionIconSize:
          (json['quickActionIconSize'] ?? 24).toDouble(),
      quickActionBubbleSize:
          (json['quickActionBubbleSize'] ?? 56).toDouble(),
      quickActionScale: (json['quickActionScale'] ?? 1.0).toDouble(),
      quickActionsCornerRadius:
          (json['quickActionsCornerRadius'] ?? 24).toDouble(),
      headerTitleSize: (json['headerTitleSize'] ?? 28).toDouble(),
      headerSubtitleSize:
          (json['headerSubtitleSize'] ?? 14).toDouble(),
      sectionTitleSize: (json['sectionTitleSize'] ?? 18).toDouble(),
      sectionSubtitleSize:
          (json['sectionSubtitleSize'] ?? 13).toDouble(),
      cardTitleSize: (json['cardTitleSize'] ?? 16).toDouble(),
      bodyTextSize: (json['bodyTextSize'] ?? 14).toDouble(),
      smallTextSize: (json['smallTextSize'] ?? 12).toDouble(),
      glassEnabled: json['glassEnabled'] ?? true,
      useFloatingCards: json['useFloatingCards'] ?? false,
      useGradientCards: json['useGradientCards'] ?? false,
      useRoundedBanners: json['useRoundedBanners'] ?? true,
      compactMode: json['compactMode'] ?? false,
      denseMode: json['denseMode'] ?? false,
      showHeaderSubtitle: json['showHeaderSubtitle'] ?? true,
      showQuickActionsLabels: json['showQuickActionsLabels'] ?? true,
      showPromoBanner: json['showPromoBanner'] ?? true,
      showSectionBackgrounds: json['showSectionBackgrounds'] ?? false,
      showSectionIcons: json['showSectionIcons'] ?? true,
      premiumGlow: json['premiumGlow'] ?? false,
      customHeaderTitle:
          (json['customHeaderTitle'] ?? 'Спортотека Футбол').toString(),
      customHeaderSubtitle:
          (json['customHeaderSubtitle'] ?? 'Вместе к победам!').toString(),
      sections: ((json['sections'] as List?) ?? const [])
          .map((e) => HomeSectionConfig.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory HomeScreenDesign.decode(String raw) {
    return HomeScreenDesign.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}