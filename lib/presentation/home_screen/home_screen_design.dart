import 'dart:convert';
import 'package:flutter/material.dart';

enum HomeSectionType {
  ringBanner,
  reels,
  tips,
  promo,
  innovations,
  events,
  venues,
  clubs,
  tickets,
  posts,
}

enum HomeSectionLayout {
  horizontal,
  grid,
  compactList,
  hero,
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

enum HomeAnimationPreset {
  none,
  soft,
  dynamic,
  premium,
}

enum HomeModePreset {
  athlete,
  coach,
  parent,
  club,
  media,
  custom,
}

enum HomeQuickActionShape {
  circle,
  roundedSquare,
  softSquare,
  pill,
}

class HomeSectionConfig {
  final HomeSectionType type;
  final bool visible;
  final bool pinned;
  final bool showSubtitle;
  final bool showIcon;
  final bool showSeeAll;
  final bool allowCollapse;
  final bool initiallyCollapsed;
  final bool highlightAsNew;
  final bool showBadge;
  final bool showDividerAbove;
  final bool showDividerBelow;

  final String? customTitle;
  final String? customSubtitle;
  final String? badgeText;

  final Color? badgeColor;
  final Color? accentOverride;

  final int itemLimit;
  final double cardWidth;
  final double cardHeight;
  final int gridColumns;
  final double aspectRatio;
  final double topSpacing;
  final double bottomSpacing;
  final double innerPadding;
  final HomeSectionLayout layout;

  const HomeSectionConfig({
    required this.type,
    this.visible = true,
    this.pinned = false,
    this.showSubtitle = true,
    this.showIcon = true,
    this.showSeeAll = true,
    this.allowCollapse = false,
    this.initiallyCollapsed = false,
    this.highlightAsNew = false,
    this.showBadge = false,
    this.showDividerAbove = false,
    this.showDividerBelow = false,
    this.customTitle,
    this.customSubtitle,
    this.badgeText,
    this.badgeColor,
    this.accentOverride,
    this.itemLimit = 6,
    this.cardWidth = 220,
    this.cardHeight = 220,
    this.gridColumns = 2,
    this.aspectRatio = 1.0,
    this.topSpacing = 0,
    this.bottomSpacing = 0,
    this.innerPadding = 0,
    this.layout = HomeSectionLayout.horizontal,
  });

  HomeSectionConfig copyWith({
    HomeSectionType? type,
    bool? visible,
    bool? pinned,
    bool? showSubtitle,
    bool? showIcon,
    bool? showSeeAll,
    bool? allowCollapse,
    bool? initiallyCollapsed,
    bool? highlightAsNew,
    bool? showBadge,
    bool? showDividerAbove,
    bool? showDividerBelow,
    String? customTitle,
    String? customSubtitle,
    String? badgeText,
    bool clearCustomTitle = false,
    bool clearCustomSubtitle = false,
    bool clearBadgeText = false,
    Color? badgeColor,
    Color? accentOverride,
    int? itemLimit,
    double? cardWidth,
    double? cardHeight,
    int? gridColumns,
    double? aspectRatio,
    double? topSpacing,
    double? bottomSpacing,
    double? innerPadding,
    HomeSectionLayout? layout,
  }) {
    return HomeSectionConfig(
      type: type ?? this.type,
      visible: visible ?? this.visible,
      pinned: pinned ?? this.pinned,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      showIcon: showIcon ?? this.showIcon,
      showSeeAll: showSeeAll ?? this.showSeeAll,
      allowCollapse: allowCollapse ?? this.allowCollapse,
      initiallyCollapsed: initiallyCollapsed ?? this.initiallyCollapsed,
      highlightAsNew: highlightAsNew ?? this.highlightAsNew,
      showBadge: showBadge ?? this.showBadge,
      showDividerAbove: showDividerAbove ?? this.showDividerAbove,
      showDividerBelow: showDividerBelow ?? this.showDividerBelow,
      customTitle: clearCustomTitle ? null : (customTitle ?? this.customTitle),
      customSubtitle: clearCustomSubtitle
          ? null
          : (customSubtitle ?? this.customSubtitle),
      badgeText: clearBadgeText ? null : (badgeText ?? this.badgeText),
      badgeColor: badgeColor ?? this.badgeColor,
      accentOverride: accentOverride ?? this.accentOverride,
      itemLimit: itemLimit ?? this.itemLimit,
      cardWidth: cardWidth ?? this.cardWidth,
      cardHeight: cardHeight ?? this.cardHeight,
      gridColumns: gridColumns ?? this.gridColumns,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      topSpacing: topSpacing ?? this.topSpacing,
      bottomSpacing: bottomSpacing ?? this.bottomSpacing,
      innerPadding: innerPadding ?? this.innerPadding,
      layout: layout ?? this.layout,
    );
  }

  static List<HomeSectionConfig> defaults() {
    return const [
      HomeSectionConfig(
        type: HomeSectionType.ringBanner,
        layout: HomeSectionLayout.hero,
        itemLimit: 1,
        cardWidth: 320,
        cardHeight: 190,
        visible: true,
        showSeeAll: false,
      ),
      HomeSectionConfig(
        type: HomeSectionType.reels,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 6,
        cardWidth: 220,
        cardHeight: 320,
        visible: true,
      ),
      HomeSectionConfig(
        type: HomeSectionType.tips,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 20,
        cardWidth: 230,
        cardHeight: 200,
        visible: true,
        showSeeAll: false,
      ),
      HomeSectionConfig(
        type: HomeSectionType.promo,
        layout: HomeSectionLayout.hero,
        itemLimit: 1,
        cardWidth: 320,
        cardHeight: 180,
        visible: true,
        showSeeAll: false,
      ),
      HomeSectionConfig(
        type: HomeSectionType.innovations,
        layout: HomeSectionLayout.grid,
        itemLimit: 4,
        gridColumns: 2,
        cardWidth: 180,
        cardHeight: 180,
        visible: true,
        showSeeAll: false,
      ),
      HomeSectionConfig(
        type: HomeSectionType.events,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 10,
        cardWidth: 240,
        cardHeight: 250,
        visible: true,
      ),
      HomeSectionConfig(
        type: HomeSectionType.venues,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 10,
        cardWidth: 240,
        cardHeight: 240,
        visible: true,
      ),
      HomeSectionConfig(
        type: HomeSectionType.clubs,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 10,
        cardWidth: 240,
        cardHeight: 240,
        visible: true,
      ),
      HomeSectionConfig(
        type: HomeSectionType.tickets,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 10,
        cardWidth: 240,
        cardHeight: 225,
        visible: true,
      ),
      HomeSectionConfig(
        type: HomeSectionType.posts,
        layout: HomeSectionLayout.horizontal,
        itemLimit: 10,
        cardWidth: 250,
        cardHeight: 260,
        visible: true,
      ),
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'visible': visible,
      'pinned': pinned,
      'showSubtitle': showSubtitle,
      'showIcon': showIcon,
      'showSeeAll': showSeeAll,
      'allowCollapse': allowCollapse,
      'initiallyCollapsed': initiallyCollapsed,
      'highlightAsNew': highlightAsNew,
      'showBadge': showBadge,
      'showDividerAbove': showDividerAbove,
      'showDividerBelow': showDividerBelow,
      'customTitle': customTitle,
      'customSubtitle': customSubtitle,
      'badgeText': badgeText,
      'badgeColor': badgeColor?.value,
      'accentOverride': accentOverride?.value,
      'itemLimit': itemLimit,
      'cardWidth': cardWidth,
      'cardHeight': cardHeight,
      'gridColumns': gridColumns,
      'aspectRatio': aspectRatio,
      'topSpacing': topSpacing,
      'bottomSpacing': bottomSpacing,
      'innerPadding': innerPadding,
      'layout': layout.name,
    };
  }

  factory HomeSectionConfig.fromMap(Map<String, dynamic> map) {
    HomeSectionType parseType(String? raw) {
      return HomeSectionType.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => HomeSectionType.posts,
      );
    }

    HomeSectionLayout parseLayout(String? raw) {
      return HomeSectionLayout.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => HomeSectionLayout.horizontal,
      );
    }

    return HomeSectionConfig(
      type: parseType(map['type']?.toString()),
      visible: map['visible'] ?? true,
      pinned: map['pinned'] ?? false,
      showSubtitle: map['showSubtitle'] ?? true,
      showIcon: map['showIcon'] ?? true,
      showSeeAll: map['showSeeAll'] ?? true,
      allowCollapse: map['allowCollapse'] ?? false,
      initiallyCollapsed: map['initiallyCollapsed'] ?? false,
      highlightAsNew: map['highlightAsNew'] ?? false,
      showBadge: map['showBadge'] ?? false,
      showDividerAbove: map['showDividerAbove'] ?? false,
      showDividerBelow: map['showDividerBelow'] ?? false,
      customTitle: map['customTitle']?.toString(),
      customSubtitle: map['customSubtitle']?.toString(),
      badgeText: map['badgeText']?.toString(),
      badgeColor:
          map['badgeColor'] != null ? Color(map['badgeColor'] as int) : null,
      accentOverride: map['accentOverride'] != null
          ? Color(map['accentOverride'] as int)
          : null,
      itemLimit: (map['itemLimit'] ?? 6) as int,
      cardWidth: (map['cardWidth'] ?? 220).toDouble(),
      cardHeight: (map['cardHeight'] ?? 220).toDouble(),
      gridColumns: (map['gridColumns'] ?? 2) as int,
      aspectRatio: (map['aspectRatio'] ?? 1.0).toDouble(),
      topSpacing: (map['topSpacing'] ?? 0).toDouble(),
      bottomSpacing: (map['bottomSpacing'] ?? 0).toDouble(),
      innerPadding: (map['innerPadding'] ?? 0).toDouble(),
      layout: parseLayout(map['layout']?.toString()),
    );
  }
}

class HomeScreenDesign {
  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color borderColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;
  final Color mutedTextColor;

  final Color headerStartColor;
  final Color headerMidColor;
  final Color headerEndColor;

  final String customHeaderTitle;
  final String customHeaderSubtitle;
  final String? greetingText;
  final String? statusText;
  final String? headerImageUrl;

  final double headerTitleSize;
  final double headerSubtitleSize;
  final double sectionTitleSize;
  final double sectionSubtitleSize;
  final double cardTitleSize;
  final double bodyTextSize;
  final double smallTextSize;
  final double textScale;

  final double headerExpandedHeight;
  final double headerCollapsedExtraHeight;

  final double cardRadius;
  final double bannerRadius;
  final double smallRadius;
  final double borderWidth;
  final double shadowOpacity;
  final double shadowBlur;
  final double cardBackgroundOpacity;
  final double cardBorderOpacity;
  final double cardContentPadding;

  final double sectionGap;
  final double pageHorizontalPadding;

  final bool showPromoBanner;
  final bool showSectionIcons;
  final bool showSectionBackgrounds;

  final bool showHeaderSubtitle;
  final bool showSearchInHeader;
  final bool showHeaderQuickActions;
  final bool showQuickActionsLabels;
  final bool showHeaderGreeting;
  final bool showHeaderAvatar;
  final bool centerHeaderContent;
  final bool showHeaderBottomFade;

  final bool useHeaderImage;
  final double headerImageOpacity;
  final double headerOverlayOpacity;

  final double quickActionBubbleSize;
  final double quickActionIconSize;
  final double quickActionsCornerRadius;
  final double quickActionBorderWidth;
  final HomeQuickActionShape quickActionShape;
  final bool quickActionUseGradient;
  final bool quickActionOutlined;
  final Color quickActionBackgroundColor;
  final Color quickActionIconColor;
  final Color quickActionInnerColor;
  final double quickActionScale;

  final bool useRoundedBanners;
  final bool useFloatingCards;
  final bool useGradientCards;
  final bool cardUseGradientBorder;
  final bool cardShowTopAccentLine;

  final bool glassEnabled;
  final double glassOpacity;
  final double blurSigma;
  final bool premiumGlow;

  final bool enableAnimatedSectionEntrance;
  final bool enableParallaxHeader;
  final bool enablePullToRefresh;
  final bool showScrollToTopButton;
  final bool rememberCollapsedSections;
  final bool autoHidePromoAfterClose;
  final bool enableHapticFeedback;
  final bool reduceMotion;
  final bool compactMode;
  final bool denseMode;

  final HomeHeaderStyle headerStyle;
  final HomeCardStyle cardStyle;
  final HomeAnimationPreset animationPreset;
  final HomeModePreset modePreset;

  final List<HomeSectionConfig> sections;

  const HomeScreenDesign({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.borderColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.headerStartColor,
    required this.headerMidColor,
    required this.headerEndColor,
    required this.customHeaderTitle,
    required this.customHeaderSubtitle,
    this.greetingText,
    this.statusText,
    this.headerImageUrl,
    required this.headerTitleSize,
    required this.headerSubtitleSize,
    required this.sectionTitleSize,
    required this.sectionSubtitleSize,
    required this.cardTitleSize,
    required this.bodyTextSize,
    required this.smallTextSize,
    required this.textScale,
    required this.headerExpandedHeight,
    required this.headerCollapsedExtraHeight,
    required this.cardRadius,
    required this.bannerRadius,
    required this.smallRadius,
    required this.borderWidth,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.cardBackgroundOpacity,
    required this.cardBorderOpacity,
    required this.cardContentPadding,
    required this.sectionGap,
    required this.pageHorizontalPadding,
    required this.showPromoBanner,
    required this.showSectionIcons,
    required this.showSectionBackgrounds,
    required this.showHeaderSubtitle,
    required this.showSearchInHeader,
    required this.showHeaderQuickActions,
    required this.showQuickActionsLabels,
    required this.showHeaderGreeting,
    required this.showHeaderAvatar,
    required this.centerHeaderContent,
    required this.showHeaderBottomFade,
    required this.useHeaderImage,
    required this.headerImageOpacity,
    required this.headerOverlayOpacity,
    required this.quickActionBubbleSize,
    required this.quickActionIconSize,
    required this.quickActionsCornerRadius,
    required this.quickActionBorderWidth,
    required this.quickActionShape,
    required this.quickActionUseGradient,
    required this.quickActionOutlined,
    required this.quickActionBackgroundColor,
    required this.quickActionIconColor,
    required this.quickActionInnerColor,
    required this.quickActionScale,
    required this.useRoundedBanners,
    required this.useFloatingCards,
    required this.useGradientCards,
    required this.cardUseGradientBorder,
    required this.cardShowTopAccentLine,
    required this.glassEnabled,
    required this.glassOpacity,
    required this.blurSigma,
    required this.premiumGlow,
    required this.enableAnimatedSectionEntrance,
    required this.enableParallaxHeader,
    required this.enablePullToRefresh,
    required this.showScrollToTopButton,
    required this.rememberCollapsedSections,
    required this.autoHidePromoAfterClose,
    required this.enableHapticFeedback,
    required this.reduceMotion,
    required this.compactMode,
    required this.denseMode,
    required this.headerStyle,
    required this.cardStyle,
    required this.animationPreset,
    required this.modePreset,
    required this.sections,
  });

  factory HomeScreenDesign.defaults() {
    return HomeScreenDesign(
      backgroundColor: const Color(0xFFF7F9FC),
      surfaceColor: Colors.white,
      cardColor: Colors.white,
      borderColor: const Color(0xFFE5E7EB),
      primaryColor: const Color(0xFF00A750),
      secondaryColor: const Color(0xFF00C060),
      textColor: const Color(0xFF18201B),
      mutedTextColor: const Color(0xFF667085),
      headerStartColor: const Color(0xFF00A750),
      headerMidColor: const Color(0xFF00B85A),
      headerEndColor: const Color(0xFF0091EA),
      customHeaderTitle: 'Спортотека',
      customHeaderSubtitle: 'Вместе к победам!',
      greetingText: 'Добро пожаловать',
      statusText: null,
      headerImageUrl: null,
      headerTitleSize: 28,
      headerSubtitleSize: 14,
      sectionTitleSize: 20,
      sectionSubtitleSize: 13,
      cardTitleSize: 16,
      bodyTextSize: 14,
      smallTextSize: 12,
      textScale: 1.0,
      headerExpandedHeight: 320,
      headerCollapsedExtraHeight: 8,
      cardRadius: 22,
      bannerRadius: 26,
      smallRadius: 16,
      borderWidth: 1,
      shadowOpacity: 0.08,
      shadowBlur: 18,
      cardBackgroundOpacity: 1.0,
      cardBorderOpacity: 1.0,
      cardContentPadding: 16,
      sectionGap: 18,
      pageHorizontalPadding: 16,
      showPromoBanner: true,
      showSectionIcons: true,
      showSectionBackgrounds: false,
      showHeaderSubtitle: true,
      showSearchInHeader: true,
      showHeaderQuickActions: true,
      showQuickActionsLabels: true,
      showHeaderGreeting: false,
      showHeaderAvatar: false,
      centerHeaderContent: false,
      showHeaderBottomFade: true,
      useHeaderImage: false,
      headerImageOpacity: 0.20,
      headerOverlayOpacity: 0.20,
      quickActionBubbleSize: 54,
      quickActionIconSize: 24,
      quickActionsCornerRadius: 22,
      quickActionBorderWidth: 1,
      quickActionShape: HomeQuickActionShape.circle,
      quickActionUseGradient: true,
      quickActionOutlined: false,
      quickActionBackgroundColor: const Color(0xFF00A750),
      quickActionIconColor: const Color(0xFF00A750),
      quickActionInnerColor: Colors.white,
      quickActionScale: 1.0,
      useRoundedBanners: true,
      useFloatingCards: false,
      useGradientCards: false,
      cardUseGradientBorder: false,
      cardShowTopAccentLine: false,
      glassEnabled: true,
      glassOpacity: 0.16,
      blurSigma: 14,
      premiumGlow: false,
      enableAnimatedSectionEntrance: true,
      enableParallaxHeader: false,
      enablePullToRefresh: true,
      showScrollToTopButton: false,
      rememberCollapsedSections: true,
      autoHidePromoAfterClose: false,
      enableHapticFeedback: true,
      reduceMotion: false,
      compactMode: false,
      denseMode: false,
      headerStyle: HomeHeaderStyle.gradient,
      cardStyle: HomeCardStyle.soft,
      animationPreset: HomeAnimationPreset.soft,
      modePreset: HomeModePreset.custom,
      sections: HomeSectionConfig.defaults(),
    );
  }

  factory HomeScreenDesign.glassMint() => HomeScreenDesign.defaults();
  factory HomeScreenDesign.darkArena() => HomeScreenDesign.defaults();
  factory HomeScreenDesign.whitePremium() => HomeScreenDesign.defaults();

  HomeScreenDesign copyWith({
    Color? backgroundColor,
    Color? surfaceColor,
    Color? cardColor,
    Color? borderColor,
    Color? primaryColor,
    Color? secondaryColor,
    Color? textColor,
    Color? mutedTextColor,
    Color? headerStartColor,
    Color? headerMidColor,
    Color? headerEndColor,
    String? customHeaderTitle,
    String? customHeaderSubtitle,
    String? greetingText,
    String? statusText,
    String? headerImageUrl,
    double? headerTitleSize,
    double? headerSubtitleSize,
    double? sectionTitleSize,
    double? sectionSubtitleSize,
    double? cardTitleSize,
    double? bodyTextSize,
    double? smallTextSize,
    double? textScale,
    double? headerExpandedHeight,
    double? headerCollapsedExtraHeight,
    double? cardRadius,
    double? bannerRadius,
    double? smallRadius,
    double? borderWidth,
    double? shadowOpacity,
    double? shadowBlur,
    double? cardBackgroundOpacity,
    double? cardBorderOpacity,
    double? cardContentPadding,
    double? sectionGap,
    double? pageHorizontalPadding,
    bool? showPromoBanner,
    bool? showSectionIcons,
    bool? showSectionBackgrounds,
    bool? showHeaderSubtitle,
    bool? showSearchInHeader,
    bool? showHeaderQuickActions,
    bool? showQuickActionsLabels,
    bool? showHeaderGreeting,
    bool? showHeaderAvatar,
    bool? centerHeaderContent,
    bool? showHeaderBottomFade,
    bool? useHeaderImage,
    double? headerImageOpacity,
    double? headerOverlayOpacity,
    double? quickActionBubbleSize,
    double? quickActionIconSize,
    double? quickActionsCornerRadius,
    double? quickActionBorderWidth,
    HomeQuickActionShape? quickActionShape,
    bool? quickActionUseGradient,
    bool? quickActionOutlined,
    Color? quickActionBackgroundColor,
    Color? quickActionIconColor,
    Color? quickActionInnerColor,
    double? quickActionScale,
    bool? useRoundedBanners,
    bool? useFloatingCards,
    bool? useGradientCards,
    bool? cardUseGradientBorder,
    bool? cardShowTopAccentLine,
    bool? glassEnabled,
    double? glassOpacity,
    double? blurSigma,
    bool? premiumGlow,
    bool? enableAnimatedSectionEntrance,
    bool? enableParallaxHeader,
    bool? enablePullToRefresh,
    bool? showScrollToTopButton,
    bool? rememberCollapsedSections,
    bool? autoHidePromoAfterClose,
    bool? enableHapticFeedback,
    bool? reduceMotion,
    bool? compactMode,
    bool? denseMode,
    HomeHeaderStyle? headerStyle,
    HomeCardStyle? cardStyle,
    HomeAnimationPreset? animationPreset,
    HomeModePreset? modePreset,
    List<HomeSectionConfig>? sections,
  }) {
    return HomeScreenDesign(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      cardColor: cardColor ?? this.cardColor,
      borderColor: borderColor ?? this.borderColor,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      textColor: textColor ?? this.textColor,
      mutedTextColor: mutedTextColor ?? this.mutedTextColor,
      headerStartColor: headerStartColor ?? this.headerStartColor,
      headerMidColor: headerMidColor ?? this.headerMidColor,
      headerEndColor: headerEndColor ?? this.headerEndColor,
      customHeaderTitle: customHeaderTitle ?? this.customHeaderTitle,
      customHeaderSubtitle:
          customHeaderSubtitle ?? this.customHeaderSubtitle,
      greetingText: greetingText ?? this.greetingText,
      statusText: statusText ?? this.statusText,
      headerImageUrl: headerImageUrl ?? this.headerImageUrl,
      headerTitleSize: headerTitleSize ?? this.headerTitleSize,
      headerSubtitleSize: headerSubtitleSize ?? this.headerSubtitleSize,
      sectionTitleSize: sectionTitleSize ?? this.sectionTitleSize,
      sectionSubtitleSize:
          sectionSubtitleSize ?? this.sectionSubtitleSize,
      cardTitleSize: cardTitleSize ?? this.cardTitleSize,
      bodyTextSize: bodyTextSize ?? this.bodyTextSize,
      smallTextSize: smallTextSize ?? this.smallTextSize,
      textScale: textScale ?? this.textScale,
      headerExpandedHeight:
          headerExpandedHeight ?? this.headerExpandedHeight,
      headerCollapsedExtraHeight:
          headerCollapsedExtraHeight ?? this.headerCollapsedExtraHeight,
      cardRadius: cardRadius ?? this.cardRadius,
      bannerRadius: bannerRadius ?? this.bannerRadius,
      smallRadius: smallRadius ?? this.smallRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      cardBackgroundOpacity:
          cardBackgroundOpacity ?? this.cardBackgroundOpacity,
      cardBorderOpacity: cardBorderOpacity ?? this.cardBorderOpacity,
      cardContentPadding: cardContentPadding ?? this.cardContentPadding,
      sectionGap: sectionGap ?? this.sectionGap,
      pageHorizontalPadding:
          pageHorizontalPadding ?? this.pageHorizontalPadding,
      showPromoBanner: showPromoBanner ?? this.showPromoBanner,
      showSectionIcons: showSectionIcons ?? this.showSectionIcons,
      showSectionBackgrounds:
          showSectionBackgrounds ?? this.showSectionBackgrounds,
      showHeaderSubtitle: showHeaderSubtitle ?? this.showHeaderSubtitle,
      showSearchInHeader: showSearchInHeader ?? this.showSearchInHeader,
      showHeaderQuickActions:
          showHeaderQuickActions ?? this.showHeaderQuickActions,
      showQuickActionsLabels:
          showQuickActionsLabels ?? this.showQuickActionsLabels,
      showHeaderGreeting: showHeaderGreeting ?? this.showHeaderGreeting,
      showHeaderAvatar: showHeaderAvatar ?? this.showHeaderAvatar,
      centerHeaderContent:
          centerHeaderContent ?? this.centerHeaderContent,
      showHeaderBottomFade:
          showHeaderBottomFade ?? this.showHeaderBottomFade,
      useHeaderImage: useHeaderImage ?? this.useHeaderImage,
      headerImageOpacity: headerImageOpacity ?? this.headerImageOpacity,
      headerOverlayOpacity:
          headerOverlayOpacity ?? this.headerOverlayOpacity,
      quickActionBubbleSize:
          quickActionBubbleSize ?? this.quickActionBubbleSize,
      quickActionIconSize:
          quickActionIconSize ?? this.quickActionIconSize,
      quickActionsCornerRadius:
          quickActionsCornerRadius ?? this.quickActionsCornerRadius,
      quickActionBorderWidth:
          quickActionBorderWidth ?? this.quickActionBorderWidth,
      quickActionShape: quickActionShape ?? this.quickActionShape,
      quickActionUseGradient:
          quickActionUseGradient ?? this.quickActionUseGradient,
      quickActionOutlined:
          quickActionOutlined ?? this.quickActionOutlined,
      quickActionBackgroundColor:
          quickActionBackgroundColor ?? this.quickActionBackgroundColor,
      quickActionIconColor:
          quickActionIconColor ?? this.quickActionIconColor,
      quickActionInnerColor:
          quickActionInnerColor ?? this.quickActionInnerColor,
      quickActionScale: quickActionScale ?? this.quickActionScale,
      useRoundedBanners: useRoundedBanners ?? this.useRoundedBanners,
      useFloatingCards: useFloatingCards ?? this.useFloatingCards,
      useGradientCards: useGradientCards ?? this.useGradientCards,
      cardUseGradientBorder:
          cardUseGradientBorder ?? this.cardUseGradientBorder,
      cardShowTopAccentLine:
          cardShowTopAccentLine ?? this.cardShowTopAccentLine,
      glassEnabled: glassEnabled ?? this.glassEnabled,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
      premiumGlow: premiumGlow ?? this.premiumGlow,
      enableAnimatedSectionEntrance:
          enableAnimatedSectionEntrance ?? this.enableAnimatedSectionEntrance,
      enableParallaxHeader:
          enableParallaxHeader ?? this.enableParallaxHeader,
      enablePullToRefresh:
          enablePullToRefresh ?? this.enablePullToRefresh,
      showScrollToTopButton:
          showScrollToTopButton ?? this.showScrollToTopButton,
      rememberCollapsedSections:
          rememberCollapsedSections ?? this.rememberCollapsedSections,
      autoHidePromoAfterClose:
          autoHidePromoAfterClose ?? this.autoHidePromoAfterClose,
      enableHapticFeedback:
          enableHapticFeedback ?? this.enableHapticFeedback,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      compactMode: compactMode ?? this.compactMode,
      denseMode: denseMode ?? this.denseMode,
      headerStyle: headerStyle ?? this.headerStyle,
      cardStyle: cardStyle ?? this.cardStyle,
      animationPreset: animationPreset ?? this.animationPreset,
      modePreset: modePreset ?? this.modePreset,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'backgroundColor': backgroundColor.value,
      'surfaceColor': surfaceColor.value,
      'cardColor': cardColor.value,
      'borderColor': borderColor.value,
      'primaryColor': primaryColor.value,
      'secondaryColor': secondaryColor.value,
      'textColor': textColor.value,
      'mutedTextColor': mutedTextColor.value,
      'headerStartColor': headerStartColor.value,
      'headerMidColor': headerMidColor.value,
      'headerEndColor': headerEndColor.value,
      'customHeaderTitle': customHeaderTitle,
      'customHeaderSubtitle': customHeaderSubtitle,
      'greetingText': greetingText,
      'statusText': statusText,
      'headerImageUrl': headerImageUrl,
      'headerTitleSize': headerTitleSize,
      'headerSubtitleSize': headerSubtitleSize,
      'sectionTitleSize': sectionTitleSize,
      'sectionSubtitleSize': sectionSubtitleSize,
      'cardTitleSize': cardTitleSize,
      'bodyTextSize': bodyTextSize,
      'smallTextSize': smallTextSize,
      'textScale': textScale,
      'headerExpandedHeight': headerExpandedHeight,
      'headerCollapsedExtraHeight': headerCollapsedExtraHeight,
      'cardRadius': cardRadius,
      'bannerRadius': bannerRadius,
      'smallRadius': smallRadius,
      'borderWidth': borderWidth,
      'shadowOpacity': shadowOpacity,
      'shadowBlur': shadowBlur,
      'cardBackgroundOpacity': cardBackgroundOpacity,
      'cardBorderOpacity': cardBorderOpacity,
      'cardContentPadding': cardContentPadding,
      'sectionGap': sectionGap,
      'pageHorizontalPadding': pageHorizontalPadding,
      'showPromoBanner': showPromoBanner,
      'showSectionIcons': showSectionIcons,
      'showSectionBackgrounds': showSectionBackgrounds,
      'showHeaderSubtitle': showHeaderSubtitle,
      'showSearchInHeader': showSearchInHeader,
      'showHeaderQuickActions': showHeaderQuickActions,
      'showQuickActionsLabels': showQuickActionsLabels,
      'showHeaderGreeting': showHeaderGreeting,
      'showHeaderAvatar': showHeaderAvatar,
      'centerHeaderContent': centerHeaderContent,
      'showHeaderBottomFade': showHeaderBottomFade,
      'useHeaderImage': useHeaderImage,
      'headerImageOpacity': headerImageOpacity,
      'headerOverlayOpacity': headerOverlayOpacity,
      'quickActionBubbleSize': quickActionBubbleSize,
      'quickActionIconSize': quickActionIconSize,
      'quickActionsCornerRadius': quickActionsCornerRadius,
      'quickActionBorderWidth': quickActionBorderWidth,
      'quickActionShape': quickActionShape.name,
      'quickActionUseGradient': quickActionUseGradient,
      'quickActionOutlined': quickActionOutlined,
      'quickActionBackgroundColor': quickActionBackgroundColor.value,
      'quickActionIconColor': quickActionIconColor.value,
      'quickActionInnerColor': quickActionInnerColor.value,
      'quickActionScale': quickActionScale,
      'useRoundedBanners': useRoundedBanners,
      'useFloatingCards': useFloatingCards,
      'useGradientCards': useGradientCards,
      'cardUseGradientBorder': cardUseGradientBorder,
      'cardShowTopAccentLine': cardShowTopAccentLine,
      'glassEnabled': glassEnabled,
      'glassOpacity': glassOpacity,
      'blurSigma': blurSigma,
      'premiumGlow': premiumGlow,
      'enableAnimatedSectionEntrance': enableAnimatedSectionEntrance,
      'enableParallaxHeader': enableParallaxHeader,
      'enablePullToRefresh': enablePullToRefresh,
      'showScrollToTopButton': showScrollToTopButton,
      'rememberCollapsedSections': rememberCollapsedSections,
      'autoHidePromoAfterClose': autoHidePromoAfterClose,
      'enableHapticFeedback': enableHapticFeedback,
      'reduceMotion': reduceMotion,
      'compactMode': compactMode,
      'denseMode': denseMode,
      'headerStyle': headerStyle.name,
      'cardStyle': cardStyle.name,
      'animationPreset': animationPreset.name,
      'modePreset': modePreset.name,
      'sections': sections.map((e) => e.toMap()).toList(),
    };
  }

  String encode() => jsonEncode(toMap());

  factory HomeScreenDesign.decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;

    T parseEnum<T>(List<T> values, String? rawName, T fallback) {
      for (final v in values) {
        if ((v as dynamic).name == rawName) return v;
      }
      return fallback;
    }

    return HomeScreenDesign(
      backgroundColor:
          Color(map['backgroundColor'] ?? const Color(0xFFF7F9FC).value),
      surfaceColor: Color(map['surfaceColor'] ?? Colors.white.value),
      cardColor: Color(map['cardColor'] ?? Colors.white.value),
      borderColor: Color(map['borderColor'] ?? const Color(0xFFE5E7EB).value),
      primaryColor:
          Color(map['primaryColor'] ?? const Color(0xFF00A750).value),
      secondaryColor:
          Color(map['secondaryColor'] ?? const Color(0xFF00C060).value),
      textColor: Color(map['textColor'] ?? const Color(0xFF18201B).value),
      mutedTextColor:
          Color(map['mutedTextColor'] ?? const Color(0xFF667085).value),
      headerStartColor:
          Color(map['headerStartColor'] ?? const Color(0xFF00A750).value),
      headerMidColor:
          Color(map['headerMidColor'] ?? const Color(0xFF00B85A).value),
      headerEndColor:
          Color(map['headerEndColor'] ?? const Color(0xFF0091EA).value),
      customHeaderTitle: map['customHeaderTitle'] ?? 'Sportoteka',
      customHeaderSubtitle:
          map['customHeaderSubtitle'] ?? 'Спортивная экосистема',
      greetingText: map['greetingText'],
      statusText: map['statusText'],
      headerImageUrl: map['headerImageUrl'],
      headerTitleSize: (map['headerTitleSize'] ?? 28).toDouble(),
      headerSubtitleSize: (map['headerSubtitleSize'] ?? 14).toDouble(),
      sectionTitleSize: (map['sectionTitleSize'] ?? 20).toDouble(),
      sectionSubtitleSize: (map['sectionSubtitleSize'] ?? 13).toDouble(),
      cardTitleSize: (map['cardTitleSize'] ?? 16).toDouble(),
      bodyTextSize: (map['bodyTextSize'] ?? 14).toDouble(),
      smallTextSize: (map['smallTextSize'] ?? 12).toDouble(),
      textScale: (map['textScale'] ?? 1.0).toDouble(),
      headerExpandedHeight: (map['headerExpandedHeight'] ?? 320).toDouble(),
      headerCollapsedExtraHeight:
          (map['headerCollapsedExtraHeight'] ?? 8).toDouble(),
      cardRadius: (map['cardRadius'] ?? 22).toDouble(),
      bannerRadius: (map['bannerRadius'] ?? 26).toDouble(),
      smallRadius: (map['smallRadius'] ?? 16).toDouble(),
      borderWidth: (map['borderWidth'] ?? 1).toDouble(),
      shadowOpacity: (map['shadowOpacity'] ?? 0.08).toDouble(),
      shadowBlur: (map['shadowBlur'] ?? 18).toDouble(),
      cardBackgroundOpacity:
          (map['cardBackgroundOpacity'] ?? 1.0).toDouble(),
      cardBorderOpacity: (map['cardBorderOpacity'] ?? 1.0).toDouble(),
      cardContentPadding: (map['cardContentPadding'] ?? 16).toDouble(),
      sectionGap: (map['sectionGap'] ?? 18).toDouble(),
      pageHorizontalPadding: (map['pageHorizontalPadding'] ?? 16).toDouble(),
      showPromoBanner: map['showPromoBanner'] ?? true,
      showSectionIcons: map['showSectionIcons'] ?? true,
      showSectionBackgrounds: map['showSectionBackgrounds'] ?? false,
      showHeaderSubtitle: map['showHeaderSubtitle'] ?? true,
      showSearchInHeader: map['showSearchInHeader'] ?? true,
      showHeaderQuickActions: map['showHeaderQuickActions'] ?? true,
      showQuickActionsLabels: map['showQuickActionsLabels'] ?? true,
      showHeaderGreeting: map['showHeaderGreeting'] ?? false,
      showHeaderAvatar: map['showHeaderAvatar'] ?? false,
      centerHeaderContent: map['centerHeaderContent'] ?? false,
      showHeaderBottomFade: map['showHeaderBottomFade'] ?? true,
      useHeaderImage: map['useHeaderImage'] ?? false,
      headerImageOpacity: (map['headerImageOpacity'] ?? 0.20).toDouble(),
      headerOverlayOpacity: (map['headerOverlayOpacity'] ?? 0.20).toDouble(),
      quickActionBubbleSize: (map['quickActionBubbleSize'] ?? 54).toDouble(),
      quickActionIconSize: (map['quickActionIconSize'] ?? 24).toDouble(),
      quickActionsCornerRadius:
          (map['quickActionsCornerRadius'] ?? 22).toDouble(),
      quickActionBorderWidth:
          (map['quickActionBorderWidth'] ?? 1).toDouble(),
      quickActionShape: parseEnum(
        HomeQuickActionShape.values,
        map['quickActionShape'],
        HomeQuickActionShape.circle,
      ),
      quickActionUseGradient: map['quickActionUseGradient'] ?? true,
      quickActionOutlined: map['quickActionOutlined'] ?? false,
      quickActionBackgroundColor: Color(
        map['quickActionBackgroundColor'] ?? const Color(0xFF00A750).value,
      ),
      quickActionIconColor: Color(
        map['quickActionIconColor'] ?? const Color(0xFF00A750).value,
      ),
      quickActionInnerColor:
          Color(map['quickActionInnerColor'] ?? Colors.white.value),
      quickActionScale: (map['quickActionScale'] ?? 1.0).toDouble(),
      useRoundedBanners: map['useRoundedBanners'] ?? true,
      useFloatingCards: map['useFloatingCards'] ?? false,
      useGradientCards: map['useGradientCards'] ?? false,
      cardUseGradientBorder: map['cardUseGradientBorder'] ?? false,
      cardShowTopAccentLine: map['cardShowTopAccentLine'] ?? false,
      glassEnabled: map['glassEnabled'] ?? true,
      glassOpacity: (map['glassOpacity'] ?? 0.16).toDouble(),
      blurSigma: (map['blurSigma'] ?? 14).toDouble(),
      premiumGlow: map['premiumGlow'] ?? false,
      enableAnimatedSectionEntrance:
          map['enableAnimatedSectionEntrance'] ?? true,
      enableParallaxHeader: map['enableParallaxHeader'] ?? false,
      enablePullToRefresh: map['enablePullToRefresh'] ?? true,
      showScrollToTopButton: map['showScrollToTopButton'] ?? false,
      rememberCollapsedSections: map['rememberCollapsedSections'] ?? true,
      autoHidePromoAfterClose: map['autoHidePromoAfterClose'] ?? false,
      enableHapticFeedback: map['enableHapticFeedback'] ?? true,
      reduceMotion: map['reduceMotion'] ?? false,
      compactMode: map['compactMode'] ?? false,
      denseMode: map['denseMode'] ?? false,
      headerStyle: parseEnum(
        HomeHeaderStyle.values,
        map['headerStyle'],
        HomeHeaderStyle.gradient,
      ),
      cardStyle: parseEnum(
        HomeCardStyle.values,
        map['cardStyle'],
        HomeCardStyle.soft,
      ),
      animationPreset: parseEnum(
        HomeAnimationPreset.values,
        map['animationPreset'],
        HomeAnimationPreset.soft,
      ),
      modePreset: parseEnum(
        HomeModePreset.values,
        map['modePreset'],
        HomeModePreset.custom,
      ),
      sections: (map['sections'] as List<dynamic>?)
              ?.map((e) => HomeSectionConfig.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .toList() ??
          HomeSectionConfig.defaults(),
    );
  }
}