// lib/presentation/player_profile_screen/cmr_player_profile_screen.dart
// Новый CMR-профиль игрока: отдельный экран с меню как в club_workspace_screen.dart.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/player_screen/player_id_resolver.dart';
import 'package:sportoteka/presentation/training_screen/add_training_screen.dart';
import 'package:sportoteka/widgets/training_history_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================
// БАЗОВЫЕ ЦВЕТА (fallback)
// =============================
class _AppColors {
  // Единая спокойная палитра как в club_workspace_screen.dart:
  // белая база + мягкие цветовые акценты из HomeScreen.
  static const Color primaryGreen = Color(0xFF1F7A4D);
  static const Color primaryGradientStart = Color(0xFFF8FAF9);
  static const Color primaryGradientEnd = Color(0xFFF2F7F4);

  static const Color background = Colors.white;
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textTertiary = Color(0xFF98A2B3);

  static const Color error = Color(0xFFD92D20);
  static const Color success = Color(0xFF1F7A4D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color white = Colors.white;
  static const Color surfaceLight = Colors.white;

  static const Color cmrDark = Color(0xFF101828);
  static const Color cmrGreen = Color(0xFF1F7A4D);
  static const Color cmrSoft = Color(0xFFF2F7F4);
  static const Color cmrBorder = Color(0xFFD7E8DE);
  static const Color cmrPanel = Colors.white;
  static const Color cmrSoftPanel = Color(0xFFF6F8FA);

  static const Color blue = Color(0xFF3B82F6);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF3B82F6);
  static const Color purpleSoft = Color(0xFFEFF6FF);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeSoft = Color(0xFFFFF8EC);
  static const Color teal = Color(0xFF1F7A4D);
  static const Color tealSoft = Color(0xFFF2F7F4);
  static const Color redSoft = Color(0xFFFEECEC);

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == error) return redSoft;
    if (color == primaryGreen || color == cmrGreen || color == success) return cmrSoft;
    return color.withOpacity(0.10);
  }

  static Color accentForIcon(IconData icon) {
    if (icon == Icons.groups_2_rounded ||
        icon == Icons.group_outlined ||
        icon == Icons.person_outline_rounded ||
        icon == Icons.person_search_rounded ||
        icon == Icons.shield_outlined ||
        icon == Icons.badge_outlined ||
        icon == Icons.numbers_rounded) {
      return blue;
    }

    if (icon == Icons.sports_soccer_rounded ||
        icon == Icons.sports_score_outlined ||
        icon == Icons.emoji_events_outlined ||
        icon == Icons.emoji_events_rounded) {
      return orange;
    }

    if (icon == Icons.calendar_month_outlined ||
        icon == Icons.calendar_month_rounded ||
        icon == Icons.event_available_outlined ||
        icon == Icons.event_available_rounded ||
        icon == Icons.calendar_today_rounded) {
      return teal;
    }

    if (icon == Icons.analytics_outlined ||
        icon == Icons.query_stats_rounded ||
        icon == Icons.show_chart_rounded ||
        icon == Icons.trending_up_rounded ||
        icon == Icons.speed_rounded) {
      return purple;
    }

    if (icon == Icons.medical_information_outlined ||
        icon == Icons.medical_information_rounded ||
        icon == Icons.health_and_safety_outlined ||
        icon == Icons.health_and_safety_rounded) {
      return cmrGreen;
    }

    if (icon == Icons.fitness_center_rounded ||
        icon == Icons.folder_copy_rounded ||
        icon == Icons.video_library_rounded ||
        icon == Icons.menu_book_outlined) {
      return cmrGreen;
    }

    return primaryGreen;
  }
}


// =============================
// МОДЕЛЬ ДИЗАЙНА ПРОФИЛЯ
// =============================
class _PlayerProfileDesign {
  final String fontFamily; // default, inter, montserrat, roboto
  final double headerRadius;
  final double cardRadius;
  final double avatarSize;
  final double titleFontSize;
  final double bodyFontSize;

  final int primaryColorValue;
  final int secondaryColorValue;
  final int backgroundColorValue;
  final int cardColorValue;
  final int textPrimaryColorValue;
  final int textSecondaryColorValue;

  final List<String> sectionOrder;

  final bool showQuickActions;
  final bool showClubCard;
  final bool showBioCard;
  final bool useHeaderGradient;

  const _PlayerProfileDesign({
    required this.fontFamily,
    required this.headerRadius,
    required this.cardRadius,
    required this.avatarSize,
    required this.titleFontSize,
    required this.bodyFontSize,
    required this.primaryColorValue,
    required this.secondaryColorValue,
    required this.backgroundColorValue,
    required this.cardColorValue,
    required this.textPrimaryColorValue,
    required this.textSecondaryColorValue,
    required this.sectionOrder,
    required this.showQuickActions,
    required this.showClubCard,
    required this.showBioCard,
    required this.useHeaderGradient,
  });

  factory _PlayerProfileDesign.defaults() {
    return const _PlayerProfileDesign(
      fontFamily: 'inter',
      headerRadius: 30,
      cardRadius: 28,
      avatarSize: 92,
      titleFontSize: 22,
      bodyFontSize: 14.5,
      primaryColorValue: 0xFF1F7A4D,
      secondaryColorValue: 0xFF101828,
      backgroundColorValue: 0xFFFFFFFF,
      cardColorValue: 0xFFFFFFFF,
      textPrimaryColorValue: 0xFF111827,
      textSecondaryColorValue: 0xFF64748B,
      sectionOrder: ['main_info', 'club_info', 'bio_info'],
      showQuickActions: true,
      showClubCard: true,
      showBioCard: true,
      useHeaderGradient: false,
    );
  }

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);
  Color get backgroundColor => Colors.white;
  Color get cardColor => Color(cardColorValue);
  Color get textPrimaryColor => Color(textPrimaryColorValue);
  Color get textSecondaryColor => Color(textSecondaryColorValue);

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'headerRadius': headerRadius,
      'cardRadius': cardRadius,
      'avatarSize': avatarSize,
      'titleFontSize': titleFontSize,
      'bodyFontSize': bodyFontSize,
      'primaryColorValue': primaryColorValue,
      'secondaryColorValue': secondaryColorValue,
      'backgroundColorValue': backgroundColorValue,
      'cardColorValue': cardColorValue,
      'textPrimaryColorValue': textPrimaryColorValue,
      'textSecondaryColorValue': textSecondaryColorValue,
      'sectionOrder': sectionOrder,
      'showQuickActions': showQuickActions,
      'showClubCard': showClubCard,
      'showBioCard': showBioCard,
      'useHeaderGradient': useHeaderGradient,
    };
  }

  factory _PlayerProfileDesign.fromJson(Map<String, dynamic> json) {
    return _PlayerProfileDesign(
      fontFamily: (json['fontFamily'] ?? 'default').toString(),
      headerRadius: (json['headerRadius'] as num?)?.toDouble() ?? 24,
      cardRadius: (json['cardRadius'] as num?)?.toDouble() ?? 18,
      avatarSize: (json['avatarSize'] as num?)?.toDouble() ?? 70,
      titleFontSize: (json['titleFontSize'] as num?)?.toDouble() ?? 20,
      bodyFontSize: (json['bodyFontSize'] as num?)?.toDouble() ?? 14,
      primaryColorValue:
          (json['primaryColorValue'] as num?)?.toInt() ?? 0xFF2563EB,
      secondaryColorValue:
          (json['secondaryColorValue'] as num?)?.toInt() ?? 0xFF1D4ED8,
      backgroundColorValue:
          (json['backgroundColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      cardColorValue:
          (json['cardColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      textPrimaryColorValue:
          (json['textPrimaryColorValue'] as num?)?.toInt() ?? 0xFF1E293B,
      textSecondaryColorValue:
          (json['textSecondaryColorValue'] as num?)?.toInt() ?? 0xFF64748B,
      sectionOrder: (json['sectionOrder'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          ['main_info', 'club_info', 'bio_info'],
      showQuickActions: json['showQuickActions'] ?? true,
      showClubCard: json['showClubCard'] ?? true,
      showBioCard: json['showBioCard'] ?? true,
      useHeaderGradient: json['useHeaderGradient'] ?? false,
    );
  }

  _PlayerProfileDesign copyWith({
    String? fontFamily,
    double? headerRadius,
    double? cardRadius,
    double? avatarSize,
    double? titleFontSize,
    double? bodyFontSize,
    int? primaryColorValue,
    int? secondaryColorValue,
    int? backgroundColorValue,
    int? cardColorValue,
    int? textPrimaryColorValue,
    int? textSecondaryColorValue,
    List<String>? sectionOrder,
    bool? showQuickActions,
    bool? showClubCard,
    bool? showBioCard,
    bool? useHeaderGradient,
  }) {
    return _PlayerProfileDesign(
      fontFamily: fontFamily ?? this.fontFamily,
      headerRadius: headerRadius ?? this.headerRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      avatarSize: avatarSize ?? this.avatarSize,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      textPrimaryColorValue:
          textPrimaryColorValue ?? this.textPrimaryColorValue,
      textSecondaryColorValue:
          textSecondaryColorValue ?? this.textSecondaryColorValue,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      showQuickActions: showQuickActions ?? this.showQuickActions,
      showClubCard: showClubCard ?? this.showClubCard,
      showBioCard: showBioCard ?? this.showBioCard,
      useHeaderGradient: useHeaderGradient ?? this.useHeaderGradient,
    );
  }
}

enum _CmrRightEditorMode {
  metrics,
  media,
  medicalRecord,
  coachNote,
  playerRating,
}

class CmrPlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> player;
  final bool embeddedInWorkspace;

  const CmrPlayerProfileScreen({
    super.key,
    required this.player,
    this.embeddedInWorkspace = false,
  });

  @override
  State<CmrPlayerProfileScreen> createState() => _CmrPlayerProfileScreenState();
}

class _CmrPlayerProfileScreenState extends State<CmrPlayerProfileScreen>
    with SingleTickerProviderStateMixin {
  static const String _apiBase = "https://sportotekaapp.ru/api";
  static const String _getOrCreatePrivateChatUrl =
      '$_apiBase/get_or_create_private_chat.php';

  List<Map<String, dynamic>> medicalRecords = [];
  List<String> metrics = [];
  List<String> mediaLinks = [];
  bool isLoading = true;

  // Diary
  List<Map<String, dynamic>> diaryItems = [];
  bool diaryLoading = false;
  String? diaryError;
  int _resolvedPlayerId = 0;

  int _selectedTabIndex = 0;
  bool _mobileHeroCollapsed = false;
  bool _showInlinePlayerEditor = false;

  // CMR desktop-window behavior for profile blocks.
  // Blocks can be opened above the profile as draggable/minimizable/maximizable
  // internal windows, like the tracker panels.
  String? _playerFloatingPane;
  String _playerFloatingTitle = 'Профиль игрока';
  IconData _playerFloatingIcon = Icons.open_in_full_rounded;
  bool _playerFloatingMinimized = false;
  bool _playerFloatingMaximized = false;
  Offset? _playerFloatingOffset;

  // Главное окно профиля: управление только в верхнем левом углу.
  bool _playerProfileRailExpanded = true;
  bool _playerProfileWindowMinimized = false;
  bool _playerProfileWindowMaximized = false;

  Color _actionAccent(IconData icon, String label) {
    final text = label.toLowerCase();

    if (text.contains('сообщ') || text.contains('напис') || text.contains('чат') || icon == Icons.chat_bubble_outline_rounded || icon == Icons.chat_bubble_rounded) {
      return _AppColors.cmrGreen;
    }

    if (text.contains('редакт') || text.contains('карточ') || text.contains('изм') || icon == Icons.edit_outlined || icon == Icons.edit_rounded) {
      return _AppColors.blue;
    }

    if (text.contains('трен') || text.contains('назнач') || icon == Icons.event_available_outlined || icon == Icons.add_task_rounded || icon == Icons.fitness_center_rounded) {
      return _AppColors.orange;
    }

    if (text.contains('удал')) return _AppColors.error;
    if (text.contains('мед') || text.contains('запись') || icon == Icons.medical_information_outlined || icon == Icons.health_and_safety_outlined) return _AppColors.cmrGreen;
    if (text.contains('метрик') || icon == Icons.query_stats_rounded || icon == Icons.analytics_outlined || icon == Icons.show_chart_rounded) return _AppColors.cmrGreen;
    if (text.contains('достиж') || icon == Icons.emoji_events_outlined || icon == Icons.emoji_events_rounded) return _AppColors.orange;

    return _AppColors.accentForIcon(icon);
  }

  String _actionHint(String label) {
    final text = label.toLowerCase();
    if (text.contains('напис') || text.contains('чат')) return 'Связь';
    if (text.contains('трен') || text.contains('назнач')) return 'Задача';
    if (text.contains('редакт') || text.contains('изм')) return 'Правка';
    if (text.contains('мед') || text.contains('запись')) return 'Контроль';
    if (text.contains('метрик')) return 'Показатель';
    if (text.contains('достиж')) return 'Результат';
    return 'Действие';
  }


  // Training PRO tabs

  // Team events
  bool eventsLoading = false;
  String? eventsError;
  List<Map<String, dynamic>> teamEvents = [];

  Map<String, dynamic>? selectedEvent;
  Map<String, dynamic>? selectedEventPlayerInfo;

  // Attendance log
  bool attendanceLoading = false;
  String? attendanceError;
  List<Map<String, dynamic>> attendanceLog = [];
  bool _attendanceShowAll = false;
  String _attendanceTypeFilter = 'all';

  // Matches
  bool matchesLoading = false;
  String? matchesError;
  List<Map<String, dynamic>> matches = [];

  // Player TTD by selected match
  bool playerTtdLoading = false;
  String? playerTtdError;
  Map<String, dynamic>? selectedTtdMatch;
  int _openingPlayerMatchId = 0;
  StateSetter? _activeSectionSheetSetState;
  List<Map<String, dynamic>> playerTtdMainRows = [];
  List<Map<String, dynamic>> playerTtdPassRows = [];
  List<Map<String, dynamic>> playerTtdGoalkeeperRows = [];
  Map<String, dynamic> playerTtdSummary = {};

  // Filters
  final TextEditingController _eventSearchC = TextEditingController();
  DateTime? _eventFilterDate;

  // team_events
  bool calendarLoading = false;
  String? calendarError;
  List<Map<String, dynamic>> calendarEvents = [];
  final TextEditingController _calendarSearchC = TextEditingController();
  DateTime? _calendarFrom;
  DateTime? _calendarTo;

  bool _trainingCalendarExpanded = false;
  bool _cmrGuideCollapsed = true;
  bool _diaryCalendarExpanded = false;
  bool _matchesCalendarExpanded = false;
  bool _testingCalendarExpanded = false;
  DateTime? _selectedTrainingDay;
  DateTime? _selectedDiaryDay;
  DateTime? _selectedMatchDay;
  DateTime? _selectedTestingDay;

  // Отдельный месяц просмотра для календарей.
  // Раньше стрелки календаря меняли выбранный день и из-за этого разделы
  // выглядели «статичными»: окно не перестраивалось, а список фильтровался
  // по первому числу месяца. Теперь месяц листается отдельно от выбранной даты.
  DateTime? _trainingCalendarMonth;
  DateTime? _matchesCalendarMonth;
  DateTime? _diaryCalendarMonth;
  DateTime? _testingCalendarMonth;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _rebuildOpenSectionSheet();
  }

  void _rebuildOpenSectionSheet() {
    final updater = _activeSectionSheetSetState;
    if (updater == null) return;
    try {
      updater(() {});
    } catch (_) {
      _activeSectionSheetSetState = null;
    }
  }

  bool _usesCmrRightDetailsPane(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1080;
  }

  bool _isWideSplitDetailsMode() {
    return _usesCmrRightDetailsPane(context) && !_showInlinePlayerEditor && _selectedTabIndex != 0;
  }

  void _openRightEditor(_CmrRightEditorMode mode, {Map<String, dynamic>? medicalRecord}) {
    if (!mounted) return;
    setState(() {
      _rightEditorMode = mode;
      _rightEditorMedicalRecord = medicalRecord == null ? null : Map<String, dynamic>.from(medicalRecord);
    });
    _rebuildOpenSectionSheet();
  }

  void _closeRightEditor() {
    if (!mounted) return;
    setState(() {
      _rightEditorMode = null;
      _rightEditorMedicalRecord = null;
    });
    _rebuildOpenSectionSheet();
  }

  bool playerTestingLoading = false;
  String? playerTestingError;
  List<Map<String, dynamic>> playerTestingSessions = [];
  List<Map<String, dynamic>> playerTestingResults = [];

  // Правый блок деталей для планшета/ПК.
  String? _selectedMetricForDetails;
  String? _selectedMediaForDetails;
  Map<String, dynamic>? _selectedMedicalRecordForDetails;
  Map<String, dynamic>? _selectedDiaryForDetails;
  Map<String, dynamic>? _selectedTestingResultForDetails;

  // Режим редактора в правой панели: для широкого экрана формы открываются
  // справа, а не отдельным модальным окном.
  _CmrRightEditorMode? _rightEditorMode;
  Map<String, dynamic>? _rightEditorMedicalRecord;


  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design
  _PlayerProfileDesign _design = _PlayerProfileDesign.defaults();
  bool _designLoading = false;
  bool _designSaving = false;
  int _trainerUserId = 0;

  // Меню перестроено под рабочий формат как на макете:
  // слева — профиль и разделы, в центре — календарь/список, справа — отчёт выбранной записи.
  // Старые индексы сохранены для совместимости с уже существующей логикой и переходами.
  final List<_CategoryTab> _categoryTabs = const [
    _CategoryTab(0, "Обзор", "Краткая сводка", Icons.home_rounded),
    _CategoryTab(5, "Матчи", "Игровая история", Icons.sports_soccer_rounded),
    _CategoryTab(4, "Тренировки", "Командные тренировки", Icons.terrain_rounded),
    _CategoryTab(54, "Назначенные", "Личные тренировки", Icons.assignment_turned_in_rounded),
    _CategoryTab(7, "Тестирование", "Результаты тестов", Icons.show_chart_rounded),
    _CategoryTab(50, "ТТД", "Технико-тактические действия", Icons.bar_chart_rounded),
    _CategoryTab(1, "Физика", "Рост, вес, состояние", Icons.health_and_safety_rounded),
    _CategoryTab(51, "Нагрузка", "Скорость, выносливость, объём", Icons.monitor_heart_rounded),
    _CategoryTab(52, "Посещаемость", "Журнал тренировок", Icons.calendar_month_rounded),
    _CategoryTab(2, "Медиа", "Достижения, фото и видео", Icons.play_circle_fill_rounded),
    _CategoryTab(3, "Медкарта", "Медицинские записи", Icons.medical_information_rounded),
    _CategoryTab(8, "Экспорт", "PDF карточка игрока", Icons.file_upload_outlined),
  ];

  // helpers
  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;

  int get _teamId => _asInt(
        widget.player["team_id"] ??
            widget.player["teamId"] ??
            widget.player["teamID"] ??
            widget.player["selectedTeamId"] ??
            widget.player["team"]?["id"] ??
            widget.player["team"]?["team_id"],
      );

  int get _playerId => _asInt(
        widget.player["id"] ??
            widget.player["player_id"] ??
            widget.player["playerId"] ??
            widget.player["user_id"],
      );

  String _asStr(dynamic v) => (v ?? "").toString();

  Color get _primary => _design.primaryColor;
  Color get _secondary => _design.secondaryColor;
  Color get _bg => _design.backgroundColor;
  Color get _card => _design.cardColor;
  Color get _textPrimary => _design.textPrimaryColor;
  Color get _textSecondary => _design.textSecondaryColor;
  Color get _textTertiary => _AppColors.textTertiary;

  String? get _fontFamily {
    switch (_design.fontFamily) {
      case 'inter':
        return 'Inter';
      case 'montserrat':
        return 'Montserrat';
      case 'roboto':
        return 'Roboto';
      default:
        return null;
    }
  }

  TextStyle _titleStyle({
    double? size,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: (size ?? _design.titleFontSize) * .90,
      fontWeight: weight,
      color: color ?? _textPrimary,
      height: 1.2,
    );
  }

  TextStyle _bodyStyle({
    double? size,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: (size ?? _design.bodyFontSize) * .90,
      fontWeight: weight,
      color: color ?? _textSecondary,
      height: 1.3,
    );
  }


  bool _isDesktopOrTablet(BuildContext context) => MediaQuery.of(context).size.width >= 720;

  double _adaptiveFont(BuildContext context, {required double mobile, required double wide}) {
    return _isDesktopOrTablet(context) ? wide : mobile;
  }

  TextStyle _cmrTitleText(
    BuildContext context, {
    double mobile = 16.2,
    double wide = 17.0,
    Color color = const Color(0xFF101828),
    FontWeight weight = FontWeight.w700,
  }) {
    return _titleStyle(
      size: _adaptiveFont(context, mobile: mobile, wide: wide),
      color: color,
      weight: weight,
    );
  }

  TextStyle _cmrSubtitleText(
    BuildContext context, {
    double mobile = 11.2,
    double wide = 12.0,
    Color color = const Color(0xFF667085),
    FontWeight weight = FontWeight.w700,
  }) {
    return _bodyStyle(
      size: _adaptiveFont(context, mobile: mobile, wide: wide),
      color: color,
      weight: weight,
    );
  }

  TextStyle _cmrBodyText(
    BuildContext context, {
    double mobile = 10.8,
    double wide = 11.6,
    Color color = const Color(0xFF667085),
    FontWeight weight = FontWeight.w700,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: _adaptiveFont(context, mobile: mobile, wide: wide),
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  String _firstNotEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = _asStr(v).trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return "";
  }

  String _playerBirthDate() {
    return _firstNotEmpty([
      widget.player["birthDate"],
      widget.player["birth_date"],
      widget.player["date_of_birth"],
      widget.player["dob"],
    ]);
  }

  String _playerClub() {
    return _firstNotEmpty([
      widget.player["club"],
      widget.player["club_name"],
      widget.player["team_name"],
      widget.player["team"],
    ]);
  }

  String _playerAge() {
    final directAge = _firstNotEmpty([
      widget.player["age"],
      widget.player["player_age"],
    ]);

    if (directAge.isNotEmpty) return directAge;

    final birth = _playerBirthDate();
    if (birth.isEmpty) return "";

    final dt = DateTime.tryParse(birth.replaceAll(' ', 'T'));
    if (dt == null) return "";

    final now = DateTime.now();
    int age = now.year - dt.year;
    final hadBirthday =
        (now.month > dt.month) || (now.month == dt.month && now.day >= dt.day);
    if (!hadBirthday) age--;

    return age.toString();
  }

  String _anyDateStr(Map<String, dynamic> x) {
    final s =
        _asStr(x["date"] ?? x["day"] ?? x["start_at"] ?? x["event_date"])
            .trim();
    if (s.isEmpty) return "";
    final tryIso = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (tryIso != null) return DateFormat('dd.MM.yyyy').format(tryIso);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _initAll();
  }

  Future<void> _initAll() async {
    _trainerUserId = await PrefUtils.getUserId() ?? 0;
    _loadMedicalRecords();
    _parseSportData();
    _parseMedia();
    _design = _PlayerProfileDesign.defaults();
    if (mounted) setState(() {});

    // На ПК и планшетах правая рабочая зона видна сразу, поэтому прогреваем
    // тренировки заранее. Без этого список появлялся только после ручного обновления.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wide = MediaQuery.of(context).size.width >= 720;
      if (wide || _selectedTabIndex == 4 || _selectedTabIndex == 54) {
        _loadTrainingSectionData(force: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CmrPlayerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = _asInt(
      oldWidget.player["id"] ??
          oldWidget.player["player_id"] ??
          oldWidget.player["playerId"] ??
          oldWidget.player["user_id"],
    );
    if (oldId != _playerId) {
      teamEvents = [];
      attendanceLog = [];
      calendarEvents = [];
      playerTestingSessions = [];
      playerTestingResults = [];
      _trainingCalendarMonth = null;
      _matchesCalendarMonth = null;
      _diaryCalendarMonth = null;
      _testingCalendarMonth = null;
      _selectedTrainingDay = null;
      _selectedDiaryDay = null;
      _selectedMatchDay = null;
      _selectedTestingDay = null;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTrainingSectionData(force: true);
      });
    }
  }

  @override
  void dispose() {
    _eventSearchC.dispose();
    _calendarSearchC.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // =============================
  // SERVER DESIGN
  // =============================
  Future<void> _loadDesignFromServer() async {
    _design = _PlayerProfileDesign.defaults();
    if (mounted) setState(() => _designLoading = false);
  }

  Future<void> _saveDesignToServer() async {
    return;
  }

  void _openDesignEditor() {
    // Режим изменения дизайна отключён: профиль всегда использует единый клубный стиль.
  }

  Widget _buildSectionReorderEditor(
    List<String> order, {
    required ValueChanged<List<String>> onChanged,
  }) {
    final labels = {
      'main_info': 'Основная информация',
      'club_info': 'Клубная информация',
      'bio_info': 'О игроке',
    };

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        final updated = [...order];
        if (newIndex > oldIndex) newIndex--;
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);
        onChanged(updated);
      },
      children: [
        for (int i = 0; i < order.length; i++)
          Container(
            key: ValueKey(order[i]),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labels[order[i]] ?? order[i],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle_rounded),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =============================
  // DATA PARSE
  // =============================
  void _parseSportData() {
    final data = widget.player['sport_data'] ?? '';
    if (data is String && data.isNotEmpty) {
      setState(() {
        metrics = data
            .split(RegExp(r'[\n,]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      });
    }
  }

  void _parseMedia() {
    final media = widget.player['media'] ?? '';
    if (media is String && media.isNotEmpty) {
      setState(() {
        mediaLinks = media
            .split(RegExp(r'[\n,]+'))
            .map((e) => e.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> _loadMedicalRecords() async {
    final userId = widget.player['user_id'];
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final uri =
          Uri.parse('$_apiBase/medical/get_medical_records.php?user_id=$userId');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success') {
          setState(() {
            medicalRecords = List<Map<String, dynamic>>.from(data['records']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading medical records: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<int> _resolvePlayerId() async {
  if (_resolvedPlayerId > 0) return _resolvedPlayerId;

  final directPlayerId = _asInt(
    widget.player["player_id"] ??
        widget.player["playerId"] ??
        widget.player["playerID"],
  );

  if (directPlayerId > 0) {
    _resolvedPlayerId = directPlayerId;
    return _resolvedPlayerId;
  }

  final userId = _asInt(widget.player["user_id"] ?? widget.player["userId"]);
  if (userId > 0) {
    final pid = await PlayerIdResolver.resolvePlayerId(
      apiBase: _apiBase,
      userId: userId,
    );

    if (pid > 0) {
      _resolvedPlayerId = pid;
      return _resolvedPlayerId;
    }
  }

  final fallbackId = _asInt(widget.player["id"]);
  if (fallbackId > 0) {
    _resolvedPlayerId = fallbackId;
    return _resolvedPlayerId;
  }

  return 0;
}
  Future<void> _loadDiary() async {
    if (diaryLoading) return;

    setState(() {
      diaryLoading = true;
      diaryError = null;
    });

    try {
      final teamId = _teamId;
      if (teamId <= 0) throw "teamId is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final url = Uri.parse(
          "$_apiBase/get_player_self_assessments.php?team_id=$teamId&player_id=$playerId");
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки дневника")
                : "Ошибка загрузки дневника")
            .toString();
      }

      final raw = (data["items"] ?? []) as List;
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        diaryItems = list;
        diaryLoading = false;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        diaryLoading = false;
        diaryError = e.toString();
        diaryItems = [];
      });
      _rebuildOpenSectionSheet();
    }
  }

  String _diaryTitle(Map<String, dynamic> x) {
    final t = _asStr(x["title"]).trim();
    return t.isNotEmpty ? t : "Тренировка";
  }

  String _diaryDate(Map<String, dynamic> x) {
    final s = _asStr(x["start_at"]).trim();
    final u = _asStr(x["updated_at"]).trim();
    return s.isNotEmpty ? s : u;
  }

  DateTime? _parseEventDate(Map<String, dynamic> e) {
    final raw = _firstNotEmpty([
      e["date"],
      e["day"],
      e["start_at"],
      e["event_date"],
      e["training_date"],
      e["created_at"],
      e["updated_at"],
    ]).trim();
    if (raw.isEmpty) return null;

    final cleaned = raw.replaceAll(' ', 'T');
    final tryIso = DateTime.tryParse(cleaned);
    if (tryIso != null) return tryIso.toLocal();

    return _tryParseRuDate(raw);
  }

  String _eventGroupKey(Map<String, dynamic> e) {
    final d = _parseEventDate(e);
    if (d == null) return "unknown";
    return DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
  }

  String _eventGroupTitle(String key) {
    if (key == "unknown") return "Без даты";
    final d = DateTime.tryParse(key);
    if (d == null) return "Без даты";
    return DateFormat('dd.MM.yyyy').format(d);
  }

  bool _isBadApiResponse(Map<String, dynamic> data) {
    final status = _asStr(data["status"]).toLowerCase();
    final success = data["success"];
    if (success == true || success == 1 || success == "1") return false;
    if (status == "success" || status == "ok") return false;
    return true;
  }

  String _apiErrorMessage(Map<String, dynamic> data, String fallback) {
    return _firstNotEmpty([data["message"], data["error"], fallback]);
  }

  List<dynamic> _firstList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v is List) return v;
      if (v is Map && v["items"] is List) return v["items"] as List;
    }
    return const [];
  }

  // Важно: в журнале посещаемости поле `player_rating` часто означает
  // «оценка игрока тренером», а не самооценку игрока. Поэтому самооценку
  // берём только из дневника / self-полей, а оценку тренера — из журнала.
  static const List<String> _ambiguousPlayerRatingKeys = [
    'player_rating',
    'player_assessment_rating',
    'player_mark',
    'player_score',
    'player_grade',
    'rating_player',
    'mark_player',
    'score_player',
    'grade_player',
  ];

  // Самооценка игрока. Важно: здесь больше нет `player_rating`.
  // В серверных ответах по журналу это поле часто означает оценку игрока
  // тренером, поэтому для самооценки используем только self/diary-поля.
  static const List<String> _playerRatingKeys = [
    'self_rating',
    'self_rate',
    'self_rating_value',
    'rating_self',
    'rating_diary',
    'player_self_rating',
    'player_self_score',
    'self_assessment',
    'self_assessment_rating',
    'self_mark',
    'self_score',
    'self_grade',
    'diary_rating',
    'diary_mark',
    'diary_score',
    'my_rating',
    'my_mark',
    'my_score',
    'personal_rating',
  ];

  static const List<String> _coachRatingKeys = [
    'coach_rating',
    'trainer_rating',
    'coach_rate',
    'trainer_rate',
    'coach_rating_value',
    'trainer_rating_value',
    'rating_coach',
    'rating_trainer',
    'rate_coach',
    'rate_trainer',
    'coach_evaluation',
    'trainer_evaluation',
    'coach_assessment_value',
    'trainer_assessment_value',
    'coach_mark',
    'trainer_mark',
    'coach_score',
    'trainer_score',
    'coach_grade',
    'trainer_grade',
    'coach_assessment',
    'trainer_assessment',
    'coach_assessment_rating',
    'trainer_assessment_rating',
    'coach_player_rating',
    'trainer_player_rating',
    'coach_player_mark',
    'trainer_player_mark',
    'attendance_rating',
    'attendance_mark',
    'attendance_score',
    'training_rating',
    'training_mark',
    'player_event_rating',
    'event_player_rating',
    'player_training_rating',
    // Старые API могли отдавать оценку тренера как player_rating:
    'player_rating',
    'player_assessment_rating',
    'player_mark',
    'player_score',
    'player_grade',
    'rating_player',
    'mark_player',
    'score_player',
    'grade_player',
    // Универсальные поля из журнала — тоже оценка тренера.
    'mark',
    'score',
    'grade',
  ];

  static const List<String> _genericRatingKeys = [
    'rating',
    'rate',
    'mark',
    'score',
    'grade',
    'assessment',
    'value',
  ];

  int? _normalizeRatingValue(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final n = value.round();
      if (n <= 0) return null;
      return n.clamp(1, 5).toInt();
    }

    if (value is Map) {
      final nested = _firstRatingValue(
        Map<String, dynamic>.from(value),
        const [
          'rating',
          'value',
          'mark',
          'score',
          'grade',
          'rate',
          'assessment',
        ],
      );
      return nested == null ? null : _normalizeRatingValue(nested);
    }

    final raw = _asStr(value).trim().toLowerCase();
    if (raw.isEmpty ||
        raw == '0' ||
        raw == 'null' ||
        raw == 'none' ||
        raw == '-' ||
        raw == '—') {
      return null;
    }

    final direct = double.tryParse(raw.replaceAll(',', '.'));
    if (direct != null) {
      final n = direct.round();
      if (n <= 0) return null;
      return n.clamp(1, 5).toInt();
    }

    final match = RegExp(r'([1-5](?:[\.,]\d+)?)').firstMatch(raw);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (parsed == null) return null;
    final n = parsed.round();
    if (n <= 0) return null;
    return n.clamp(1, 5).toInt();
  }

  List<String> _expandedRatingKeys(List<String> keys) {
    final set = <String>{...keys};
    final hasPlayerKey = keys.any((k) => _playerRatingKeys.contains(k));
    final hasCoachKey = keys.any((k) => _coachRatingKeys.contains(k));
    if (hasPlayerKey) set.addAll(_playerRatingKeys);
    if (hasCoachKey) set.addAll(_coachRatingKeys);
    return set.toList(growable: false);
  }

  dynamic _firstRatingValue(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) return null;

    final asksPlayerRating = keys.any(
      (k) => _playerRatingKeys.contains(k) || k == 'player_rating',
    );
    final asksCoachRating = keys.any(
      (k) => _coachRatingKeys.contains(k) ||
          k == 'coach_rating' ||
          k == 'trainer_rating',
    );
    final playerRatingIsFromDiary = row['_player_rating_from_diary'] == true ||
        _asStr(row['_rating_source']).toLowerCase() == 'diary' ||
        _asStr(row['_source']).toLowerCase() == 'diary';

    for (final key in _expandedRatingKeys(keys)) {
      if (!row.containsKey(key)) continue;

      final ambiguousPlayerKey = _ambiguousPlayerRatingKeys.contains(key);

      // Без этого `player_rating` из журнала посещаемости попадал в
      // «Оценку игрока». В профиле игрока это поле показываем как
      // самооценку только после явного переноса из дневника.
      if (asksPlayerRating && ambiguousPlayerKey && !playerRatingIsFromDiary) {
        continue;
      }

      // Для оценки тренера `player_rating` из журнала остаётся допустимым
      // резервным полем. Самооценка игрока хранится отдельно в `self_rating`,
      // поэтому здесь его больше не отбрасываем.

      final normalized = _normalizeRatingValue(row[key]);
      if (normalized != null) return normalized;
    }

    for (final key in const [
      'attendance',
      'event_player',
      'player_event',
      'assessment',
      'self_assessment',
      'player_assessment',
      'coach_assessment',
      'trainer_assessment',
      'info',
      'data',
    ]) {
      final nested = row[key];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        if (playerRatingIsFromDiary && !nestedMap.containsKey('_player_rating_from_diary')) {
          nestedMap['_player_rating_from_diary'] = true;
        }
        final value = _firstRatingValue(nestedMap, keys);
        if (value != null) return value;
      }
    }

    return null;
  }

  String _attendanceStatusOf(Map<String, dynamic> row) {
    final s = _firstNotEmpty([
      row["status"],
      row["attendance_status"],
      row["presence_status"],
      row["visit_status"],
    ]).trim().toLowerCase();
    if (s == "present" || s == "присутствует" || s == "yes") return "present";
    if (s == "absent" || s == "отсутствует" || s == "no") return "absent";
    if (s == "sick" || s == "болен") return "sick";
    if (s == "late" || s == "опоздал") return "late";
    if (s == "injured" || s == "trauma" || s == "травма") return "injured";
    if (s == "individual") return "individual";
    if (s == "dayoff" || s == "day_off") return "dayoff";
    if (s.isEmpty || s == "null" || s == "none") return "unset";
    return s;
  }

  void _mergeEventFallbackInfo(Map<String, dynamic> target, Map<String, dynamic>? source) {
    if (source == null) return;

    bool isEmptyValue(dynamic value) {
      final s = _asStr(value).trim().toLowerCase();
      return s.isEmpty || s == 'null' || s == '-' || s == '—';
    }

    void put(String key, List<String> sourceKeys) {
      if (!isEmptyValue(target[key])) return;
      for (final k in sourceKeys) {
        final v = source[k];
        if (!isEmptyValue(v)) {
          target[key] = v;
          return;
        }
      }
    }

    bool hasCanonicalCoachRating() {
      return _normalizeRatingValue(target['coach_rating']) != null ||
          _normalizeRatingValue(target['trainer_rating']) != null ||
          _normalizeRatingValue(target['coach_assessment']) != null ||
          _normalizeRatingValue(target['trainer_assessment']) != null;
    }

    void putRating(String key, List<String> sourceKeys) {
      // Для тренерской оценки нельзя считать raw `player_rating` в target
      // уже найденной coach-оценкой: дальше дневник может перезаписать
      // `player_rating`, и тренер снова станет прочерком.
      if (key == 'coach_rating') {
        if (hasCanonicalCoachRating()) return;
      } else if (_firstRatingValue(target, [key]) != null) {
        return;
      }

      final value = _firstRatingValue(source, sourceKeys);
      if (value != null) target[key] = value;
    }

    // Самооценку игрока переносим только из явных self/diary-полей.
    // Храним её в отдельном canonical-поле `self_rating`, чтобы она не
    // конфликтовала с `player_rating` из журнала посещаемости.
    putRating('self_rating', const [
      'self_rating',
      'self_assessment',
      'self_assessment_rating',
      'self_mark',
      'self_score',
      'self_grade',
      'diary_rating',
      'diary_mark',
      'diary_score',
      'my_rating',
      'my_mark',
      'my_score',
    ]);
    if (_firstRatingValue(target, _playerRatingKeys) != null) {
      target['_player_rating_from_diary'] = true;
    }

    // Оценка тренера может приходить как coach_rating/trainer_rating,
    // а в старом журнале — как player_rating/rating/mark/score.
    putRating('coach_rating', _coachRatingKeys);

    // Если сервер вернул только универсальное поле `rating`/`rate`,
    // считаем его оценкой тренера для записей посещаемости/тренировки.
    // Самооценка игрока подтягивается отдельно из get_player_self_assessments.php.
    if (!hasCanonicalCoachRating()) {
      final genericRating = _firstRatingValue(source, _genericRatingKeys);
      if (genericRating != null) target['coach_rating'] = genericRating;
    }
    put('coach_comment', const [
      'coach_comment',
      'trainer_comment',
      'coach_feedback',
      'trainer_feedback',
      'feedback',
      'comment',
    ]);
    put('coach_note', const [
      'coach_note',
      'trainer_note',
      'note_coach',
      'coach_notes',
      'trainer_notes',
    ]);
    put('player_note', const [
      'player_note',
      'self_note',
      'diary_note',
      'player_comment',
      'self_comment',
    ]);
    put('status', const [
      'status',
      'attendance_status',
      'presence_status',
      'visit_status',
    ]);
    put('reason', const ['reason', 'absence_reason']);
  }

  Map<String, dynamic> _normalizeTrainingEvent(Map<String, dynamic> e) {
    final out = Map<String, dynamic>.from(e);
    out["event_id"] ??= out["id"] ?? out["training_id"];
    out["title"] = _firstNotEmpty([out["title"], out["event_title"], out["name"], "Тренировка"]);
    out["date"] = _firstNotEmpty([
  out["date"],
  out["day"],
  out["start_at"],
  out["event_date"],
  out["training_date"],
]);
    _mergeEventFallbackInfo(out, e);
    return out;
  }

  Map<String, dynamic> _normalizeAttendanceRow(Map<String, dynamic> e) {
    final out = Map<String, dynamic>.from(e);
    out["event_id"] ??= out["id"] ?? out["team_event_id"] ?? out["training_id"];
    out["title"] = _firstNotEmpty([out["title"], out["event_title"], out["name"], "Тренировка"]);
   out["date"] = _firstNotEmpty([
  out["date"],
  out["day"],
  out["start_at"],
  out["event_date"],
  out["training_date"],
]);
    out["status"] = _attendanceStatusOf(out);
    _mergeEventFallbackInfo(out, e);
    return out;
  }

  List<Map<String, dynamic>> _mergeAttendanceWithTrainingHistory(List<Map<String, dynamic>> base) {
    final byEvent = <int, Map<String, dynamic>>{};
    for (final row in base) {
      final id = _asInt(row["event_id"] ?? row["id"]);
      if (id > 0) byEvent[id] = row;
    }

    for (final ev in teamEvents) {
      final id = _asInt(ev["event_id"] ?? ev["id"]);
      if (id <= 0) continue;
      final normalizedEvent = _normalizeAttendanceRow(ev);
      final hasUsefulAttendance = _attendanceStatusOf(normalizedEvent) != "unset" ||
          _firstRatingValue(normalizedEvent, _coachRatingKeys) != null ||
          _firstNotEmpty([
            normalizedEvent["coach_comment"],
            normalizedEvent["trainer_comment"],
            normalizedEvent["comment"],
          ]).isNotEmpty;
      if (!hasUsefulAttendance) continue;

      final merged = {
        ...normalizedEvent,
        ...?byEvent[id],
      };
      byEvent[id] = _normalizeAttendanceRow(merged);
    }

    final out = byEvent.values.toList();
    if (out.isEmpty && base.isNotEmpty) return base;
    return out;
  }

  int _trainingRowEventId(Map<String, dynamic> row) {
    return _asInt(
      row['event_id'] ??
          row['team_event_id'] ??
          row['training_id'] ??
          row['eventId'] ??
          row['teamEventId'] ??
          row['id'],
    );
  }

  String _trainingDateKeyOf(Map<String, dynamic> row) {
    final date = _parseEventDate(row);
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));
  }

  String _trainingTitleKeyOf(Map<String, dynamic> row) {
    return _firstNotEmpty([row['title'], row['event_title'], row['name']])
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _trainingTypeKeyOf(Map<String, dynamic> row) {
    return _firstNotEmpty([row['type'], row['training_type'], row['category'], row['event_type']])
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _trainingTimeKeyOf(Map<String, dynamic> row) {
    final raw = _firstNotEmpty([
      row['start_at'],
      row['start_time'],
      row['time'],
      row['event_time'],
      row['training_time'],
    ]).trim();
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (parsed != null) return DateFormat('HH:mm').format(parsed.toLocal());
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(raw);
    if (match == null) return '';
    return "${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}";
  }
  bool _sameTrainingRecord(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = _trainingRowEventId(a);
    final bId = _trainingRowEventId(b);
    if (aId > 0 && bId > 0 && aId == bId) return true;

    final aDate = _trainingDateKeyOf(a);
    final bDate = _trainingDateKeyOf(b);
    if (aDate.isEmpty || bDate.isEmpty || aDate != bDate) return false;

    final aTitle = _trainingTitleKeyOf(a);
    final bTitle = _trainingTitleKeyOf(b);
    final sameTitle = aTitle.isNotEmpty &&
        bTitle.isNotEmpty &&
        (aTitle == bTitle || aTitle.contains(bTitle) || bTitle.contains(aTitle));
    if (sameTitle) return true;

    final aType = _trainingTypeKeyOf(a);
    final bType = _trainingTypeKeyOf(b);
    final aTime = _trainingTimeKeyOf(a);
    final bTime = _trainingTimeKeyOf(b);
    if (aType.isNotEmpty && bType.isNotEmpty && aType == bType) {
      if (aTime.isEmpty || bTime.isEmpty || aTime == bTime) return true;
    }

    return false;
  }

  void _mergeTrainingCandidate(Map<String, dynamic> target, Map<String, dynamic>? source) {
    if (source == null) return;

    bool empty(dynamic value) {
      final s = _asStr(value).trim().toLowerCase();
      return s.isEmpty || s == 'null' || s == '-' || s == '—';
    }

    source.forEach((key, value) {
      if (value is Map || value is List) return;

      final k = key.toLowerCase();
      final isRatingLike = _playerRatingKeys.contains(key) ||
          _coachRatingKeys.contains(key) ||
          _genericRatingKeys.contains(key) ||
          k.contains('rating') ||
          k.contains('mark') ||
          k.contains('score') ||
          k.contains('grade') ||
          k.contains('assessment');

      // Рейтинги не копируем «как есть»: сначала нормализуем их в
      // canonical-поля `coach_rating` и `player_rating`. Именно здесь
      // раньше `player_rating` из журнала становился оценкой игрока.
      if (isRatingLike) return;

      if (empty(target[key]) && !empty(value)) target[key] = value;
    });

    final sourceStatus = _attendanceStatusOf(source);
    if (_attendanceStatusOf(target) == 'unset' && sourceStatus != 'unset') {
      target['status'] = sourceStatus;
    }

    _mergeEventFallbackInfo(target, source);
  }

  Map<String, dynamic>? _findTrainingFallbackForRow(Map<String, dynamic> row) {
    final sources = <Map<String, dynamic>>[
      ...attendanceLog,
      ...teamEvents,
      ...calendarEvents,
      if (selectedEvent != null) selectedEvent!,
      if (selectedEventPlayerInfo != null) selectedEventPlayerInfo!,
    ];

    for (final source in sources) {
      if (_sameTrainingRecord(row, source)) return source;
    }
    return null;
  }

  void _mergeDiaryFallback(Map<String, dynamic> target) {
    final targetDate = _trainingDateKeyOf(target);
    if (targetDate.isEmpty || diaryItems.isEmpty) return;

    final targetTitle = _trainingTitleKeyOf(target);
    for (final diary in diaryItems) {
      final diaryDate = _trainingDateKeyOf(diary);
      if (diaryDate != targetDate) continue;

      final diaryTitle = _trainingTitleKeyOf(diary);
      final titleMatches = targetTitle.isEmpty ||
          diaryTitle.isEmpty ||
          targetTitle == diaryTitle ||
          targetTitle.contains(diaryTitle) ||
          diaryTitle.contains(targetTitle);
      if (!titleMatches) continue;

      final rating = _firstRatingValue(
        {
          ...diary,
          '_player_rating_from_diary': true,
          '_rating_source': 'diary',
        },
        [
          ..._playerRatingKeys,
          ..._genericRatingKeys,
        ],
      );
      if (rating != null && _firstRatingValue(target, _playerRatingKeys) == null) {
        target['self_rating'] = rating;
        target['_player_rating_from_diary'] = true;
        target['_rating_source'] = 'diary';
      }

      final note = _firstNotEmpty([
        diary['player_note'],
        diary['self_note'],
        diary['diary_note'],
        diary['note'],
        diary['comment'],
      ]).trim();
      if (note.isNotEmpty && _asStr(target['player_note']).trim().isEmpty) {
        target['player_note'] = note;
      }
      return;
    }
  }

  Map<String, dynamic> _enrichTrainingRecord(Map<String, dynamic> row) {
    final out = _normalizeAttendanceRow(row);
    final fallback = _findTrainingFallbackForRow(out);
    _mergeTrainingCandidate(out, fallback);
    _mergeDiaryFallback(out);
    return _normalizeAttendanceRow(out);
  }

  List<Map<String, dynamic>> _dedupeAndEnrichTrainingRows(Iterable<Map<String, dynamic>> rows) {
    final merged = <Map<String, dynamic>>[];

    for (final raw in rows) {
      final enriched = _enrichTrainingRecord(raw);
      if (_parseEventDate(enriched) == null) continue;

      final index = merged.indexWhere((x) => _sameTrainingRecord(x, enriched));
      if (index >= 0) {
        final combined = <String, dynamic>{
          ...enriched,
          ...merged[index],
        };
        _mergeTrainingCandidate(combined, enriched);
        _mergeTrainingCandidate(combined, merged[index]);
        _mergeDiaryFallback(combined);
        merged[index] = _normalizeAttendanceRow(combined);
      } else {
        merged.add(enriched);
      }
    }

    merged.sort((a, b) {
      final da = _parseEventDate(a) ?? DateTime(1970);
      final db = _parseEventDate(b) ?? DateTime(1970);
      return db.compareTo(da);
    });

    return merged;
  }

  List<Map<String, dynamic>> _trainingCalendarItems() {
    // Календарь тренировок должен показывать события команды,
    // но оценки/статусы брать именно по текущему игроку.
    // Поэтому сначала кладём attendanceLog: при объединении записей
    // свежая персональная оценка игрока имеет приоритет над общим teamEvents.
    return _dedupeAndEnrichTrainingRows([
      ...attendanceLog,
      ...teamEvents,
    ]);
  }

  Future<void> _loadTrainingSectionData({bool force = false}) async {
    if (_teamId <= 0) return;

    await _loadTeamCalendar(force: force);
    await _loadPlayerTrainingHistory(force: force);
    await _loadAttendanceLog(force: force);
    if (!diaryLoading && (force || diaryItems.isEmpty)) {
      await _loadDiary();
    }
    _rebuildOpenSectionSheet();
  }

  Future<void> _loadTrainingMonth(DateTime month, {bool force = false}) async {
    if (_teamId <= 0) return;
    _trainingCalendarMonth = DateTime(month.year, month.month, 1);
    await _loadTeamCalendar(force: force);
    await _loadPlayerTrainingHistory(force: force);
    await _loadAttendanceLog(force: force);
    if (!diaryLoading && (force || diaryItems.isEmpty)) {
      await _loadDiary();
    }
    _rebuildOpenSectionSheet();
  }

  Future<void> _loadPlayerTrainingHistory({bool force = false}) async {
    if (eventsLoading) return;
    if (!force && teamEvents.isNotEmpty) return;

    setState(() {
      eventsLoading = true;
      eventsError = null;
    });

    try {
      final teamId = _teamId;
      if (teamId <= 0) throw "team_id is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final now = DateTime.now();
      final selectedDay = _selectedTrainingDay ?? _eventFilterDate;
      // Важно: месяц просмотра календаря живёт отдельно от выбранного дня.
      // Так стрелки календаря листают месяц, а не фильтруют список по первому числу.
      final monthBase = _trainingCalendarMonth ?? selectedDay ?? now;
      final from = DateTime(monthBase.year, monthBase.month, 1);
      final to = DateTime(monthBase.year, monthBase.month + 1, 1);

      List<Map<String, dynamic>> list = [];

      try {
        final url = Uri.parse(
          "$_apiBase/get_player_training_history.php"
          "?team_id=$teamId"
          "&player_id=$playerId"
          "&from=${DateFormat('yyyy-MM-dd').format(from)}"
          "&to=${DateFormat('yyyy-MM-dd').format(to)}",
        );

        final res = await http.get(url).timeout(const Duration(seconds: 12));
        final data = _decodeResponseMap(res.body);

        if (!_isBadApiResponse(data)) {
          final raw = _firstList(data, const ["items", "events", "data", "rows"]);
          list = raw
              .whereType<Map>()
              .map((e) => _normalizeTrainingEvent(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {
        // Ниже есть резервная загрузка из общего календаря команды.
      }

      // Резерв: если история игрока пустая, берём тренировки из общего календаря команды.
      // Это убирает ситуацию, когда новый календарь отмечает даты, но список тренировок не появляется.
      if (list.isEmpty) {
        final clubId =
            _asInt(widget.player["club_id"] ?? widget.player["clubId"] ?? 0);
        final url = Uri.parse(
          "$_apiBase/get_team_events.php"
          "?team_id=$teamId"
          "&club_id=$clubId"
          "&from=${_fmtYmd(from)}"
          "&to=${_fmtYmd(to)}",
        );

        final res = await http.get(url).timeout(const Duration(seconds: 12));
        final data = _decodeResponseMap(res.body);
        if (_isBadApiResponse(data)) {
          throw _apiErrorMessage(data, "Ошибка загрузки истории тренировок");
        }

        final raw = _firstList(data, const ["items", "events", "data", "rows"]);
        list = raw
            .whereType<Map>()
            .map((e) => _normalizeTrainingEvent(Map<String, dynamic>.from(e)))
            .where((e) => _looksLikeTrainingEvent(e))
            .toList();
      }

      list = _dedupeAndEnrichTrainingRows(list);

      list.sort((a, b) {
        final da = _parseEventDate(a) ?? DateTime(1970);
        final db = _parseEventDate(b) ?? DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        teamEvents = list;
        eventsLoading = false;

        if (selectedEvent != null) {
          final selId =
              _asInt(selectedEvent?["event_id"] ?? selectedEvent?["id"]);
          final stillExists =
              teamEvents.any((x) => _asInt(x["event_id"] ?? x["id"]) == selId);
          if (!stillExists) {
            selectedEvent = null;
            selectedEventPlayerInfo = null;
          }
        }
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        eventsLoading = false;
        eventsError = e.toString();
        teamEvents = [];
        selectedEvent = null;
        selectedEventPlayerInfo = null;
      });
      _rebuildOpenSectionSheet();
    }
  }

  bool _looksLikeTrainingEvent(Map<String, dynamic> e) {
    final type = _firstNotEmpty([
      e["type"],
      e["event_type"],
      e["category"],
      e["kind"],
    ]).trim().toLowerCase();
    final title = _firstNotEmpty([
      e["title"],
      e["event_title"],
      e["name"],
    ]).trim().toLowerCase();

    if (type.isEmpty && title.isEmpty) return true;
    return type.contains("train") ||
        type.contains("training") ||
        type.contains("трен") ||
        title.contains("трен") ||
        title.contains("training");
  }


  int _teamIdForSelectedEvent([int eventId = 0]) {
    final fromSelected = _asInt(
      selectedEvent?['team_id'] ??
          selectedEvent?['teamId'] ??
          selectedEvent?['teamID'] ??
          selectedEvent?['team'],
    );
    if (fromSelected > 0) return fromSelected;

    final fromInfo = _asInt(
      selectedEventPlayerInfo?['team_id'] ??
          selectedEventPlayerInfo?['teamId'] ??
          selectedEventPlayerInfo?['teamID'] ??
          selectedEventPlayerInfo?['team'],
    );
    if (fromInfo > 0) return fromInfo;

    for (final list in [attendanceLog, teamEvents, calendarEvents]) {
      for (final row in list) {
        if (eventId > 0 && _trainingRowEventId(row) != eventId) continue;
        final id = _asInt(row['team_id'] ?? row['teamId'] ?? row['teamID'] ?? row['team']);
        if (id > 0) return id;
      }
    }

    return _teamId;
  }

  Future<Map<String, dynamic>?> _fetchTeamAttendanceInfoForEvent({
    required int eventId,
    required int playerId,
  }) async {
    if (eventId <= 0 || playerId <= 0) return null;

    final effectiveTeamId = _teamIdForSelectedEvent(eventId);
    if (effectiveTeamId <= 0) return null;

    try {
      final uri = Uri.parse('$_apiBase/get_team_attendance.php').replace(
        queryParameters: {
          'team_id': '$effectiveTeamId',
          'event_id': '$eventId',
          'training_id': '$eventId',
          'player_id': '$playerId',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = _decodeResponseMap(res.body);
      if (_isBadApiResponse(data)) return null;

      final raw = data['items'] ?? data['attendance'] ?? data['data'] ?? data['rows'];
      if (raw is Map) {
        final direct = raw[playerId.toString()] ?? raw[playerId];
        if (direct is Map) {
          return _normalizeAttendanceRow({
            'team_id': effectiveTeamId,
            'event_id': eventId,
            'training_id': eventId,
            'player_id': playerId,
            ...Map<String, dynamic>.from(direct),
          });
        }

        for (final entry in raw.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final row = Map<String, dynamic>.from(value);
          final rowPlayerId = _asInt(row['player_id'] ?? row['user_id'] ?? row['athlete_id'] ?? entry.key);
          if (rowPlayerId == playerId) {
            return _normalizeAttendanceRow({
              'team_id': effectiveTeamId,
              'event_id': eventId,
              'training_id': eventId,
              'player_id': playerId,
              ...row,
            });
          }
        }
      }

      if (raw is List) {
        for (final item in raw.whereType<Map>()) {
          final row = Map<String, dynamic>.from(item);
          final rowPlayerId = _asInt(row['player_id'] ?? row['user_id'] ?? row['athlete_id']);
          if (rowPlayerId == playerId) {
            return _normalizeAttendanceRow({
              'team_id': effectiveTeamId,
              'event_id': eventId,
              'training_id': eventId,
              'player_id': playerId,
              ...row,
            });
          }
        }
      }
    } catch (_) {
      // Это резервный источник из журнала команды. Если он недоступен,
      // просто показываем данные из истории игрока и дневника.
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchPlayerAttendanceItems({
    required int teamId,
    required int playerId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final uri = Uri.parse('$_apiBase/get_player_attendance.php').replace(
        queryParameters: {
          'player_id': '$playerId',
          'team_id': '$teamId',
          'from': DateFormat('yyyy-MM-dd').format(from),
          'to': DateFormat('yyyy-MM-dd').format(to.subtract(const Duration(days: 1))),
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = _decodeResponseMap(res.body);
      if (_isBadApiResponse(data)) return const [];

      final raw = data['items'] ?? data['attendance'] ?? data['data'] ?? data['rows'] ?? [];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => _normalizeAttendanceRow(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (raw is Map) {
        return raw.entries.map((entry) {
          final entryValue = entry.value;
          final value = entryValue is Map
              ? Map<String, dynamic>.from(entryValue)
              : <String, dynamic>{};
          return _normalizeAttendanceRow({
            'player_id': playerId,
            'event_id': entry.key.toString(),
            ...value,
          });
        }).toList();
      }
    } catch (_) {
      // Резервный endpoint может отсутствовать на части серверов.
    }
    return const [];
  }

Future<void> _loadPlayerInfoForEvent(int eventId) async {
  setState(() => selectedEventPlayerInfo = null);
  _rebuildOpenSectionSheet();

  try {
    final playerId = await _resolvePlayerId();
    if (playerId <= 0) throw "Не удалось определить player_id";

    final info = <String, dynamic>{'event_id': eventId, 'player_id': playerId};
    String? apiError;

    try {
      final effectiveTeamId = _teamIdForSelectedEvent(eventId);
      
      // **ВАЖНО: Сначала загружаем из основного источника - журнала посещаемости команды**
      final teamAttendance = await _fetchTeamAttendanceInfoForEvent(
        eventId: eventId,
        playerId: playerId,
      );
      
      if (teamAttendance != null) {
        _mergeTrainingCandidate(info, teamAttendance);
      }
      
      // Затем догружаем из дополнительного API если нужно
      final url = Uri.parse(
        "$_apiBase/get_player_event_info.php?event_id=$eventId&player_id=$playerId&team_id=$effectiveTeamId&training_id=$eventId"
      );
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = _decodeResponseMap(res.body);

      if (!_isBadApiResponse(data)) {
        final rawInfo = data["info"] ?? data["item"] ?? data["data"] ?? {};
        if (rawInfo is Map) {
          _mergeTrainingCandidate(info, Map<String, dynamic>.from(rawInfo));
        }
      }
    } catch (e) {
      apiError = e.toString();
    }

    _mergeTrainingCandidate(info, selectedEvent);
    _mergeDiaryFallback(info);

    // **ВАЖНО: Убеждаемся, что оценка тренера из основного источника не перезаписана**
    final coachRating = _firstRatingValue(info, _coachRatingKeys);
    if (coachRating != null) {
      info['coach_rating'] = coachRating;
      info['trainer_rating'] = coachRating;
    }

    final hasUsefulInfo = _attendanceStatusOf(info) != 'unset' ||
        _firstRatingValue(info, _playerRatingKeys) != null ||
        _firstRatingValue(info, _coachRatingKeys) != null ||
        _firstNotEmpty([
          info['title'],
          info['event_title'],
          info['name'],
          info['date'],
          info['start_at'],
          info['coach_comment'],
          info['trainer_comment'],
          info['comment'],
          info['coach_note'],
          info['trainer_note'],
          info['note_coach'],
          info['player_note'],
        ]).trim().isNotEmpty;

    if (!hasUsefulInfo && apiError != null) throw apiError;

    if (!mounted) return;
    setState(() => selectedEventPlayerInfo = _normalizeAttendanceRow(info));
    _rebuildOpenSectionSheet();
  } catch (e) {
    if (!mounted) return;
    setState(() {
      selectedEventPlayerInfo = {"error": e.toString()};
    });
    _rebuildOpenSectionSheet();
  }
}


  Future<void> _loadAttendanceLog({bool force = false}) async {
    if (attendanceLoading) return;
    if (!force && attendanceLog.isNotEmpty) return;

    setState(() {
      attendanceLoading = true;
      attendanceError = null;
    });

    try {
      final teamId = _teamId;
      if (teamId <= 0) throw "team_id is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final now = DateTime.now();
      final selectedDay = _selectedTrainingDay ?? _eventFilterDate;
      // Важно: месяц просмотра календаря живёт отдельно от выбранного дня.
      final monthBase = _trainingCalendarMonth ?? selectedDay ?? now;
      final from = DateTime(monthBase.year, monthBase.month, 1);
      final to = DateTime(monthBase.year, monthBase.month + 1, 1);

      final url = Uri.parse(
        "$_apiBase/get_player_attendance_log.php"
        "?team_id=$teamId"
        "&player_id=$playerId"
        "&from=${DateFormat('yyyy-MM-dd').format(from)}"
        "&to=${DateFormat('yyyy-MM-dd').format(to)}",
      );

      dynamic rawItems = [];
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 12));
        final data = _decodeResponseMap(res.body);
        if (!_isBadApiResponse(data)) {
          rawItems = data["items"] ?? data["attendance"] ?? data["data"] ?? data["rows"] ?? [];
        }
      } catch (_) {
        // Ниже есть резервный источник get_player_attendance.php.
      }

      List<Map<String, dynamic>> list = [];

      if (rawItems is List) {
        list = rawItems
            .whereType<Map>()
            .map((e) => _normalizeAttendanceRow(Map<String, dynamic>.from(e)))
            .toList();
      } else if (rawItems is Map) {
        list = rawItems.entries.map((entry) {
          final value = entry.value is Map
              ? Map<String, dynamic>.from(entry.value)
              : <String, dynamic>{};
          return _normalizeAttendanceRow({
            'event_id': value['event_id'] ?? value['team_event_id'] ?? value['training_id'] ?? entry.key.toString(),
            'player_id': value['player_id'] ?? value['user_id'] ?? playerId,
            ...value,
          });
        }).toList();
      }

      final playerAttendance = await _fetchPlayerAttendanceItems(
        teamId: teamId,
        playerId: playerId,
        from: from,
        to: to,
      );

      list = _mergeAttendanceWithTrainingHistory([...list, ...playerAttendance]);
      list = _dedupeAndEnrichTrainingRows(list);

      list.sort((a, b) {
        final da = _parseEventDate(a) ?? DateTime(1970);
        final db = _parseEventDate(b) ?? DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        attendanceLog = list;
        attendanceLoading = false;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attendanceLoading = false;
        attendanceError = e.toString();
        attendanceLog = [];
      });
      _rebuildOpenSectionSheet();
    }
  }

  Future<void> _saveCoachNoteForEvent({
    required int eventId,
    required int playerId,
    required String note,
  }) async {
    final url = Uri.parse("$_apiBase/save_player_event_note.php");

    final res = await http
        .post(
          url,
          headers: {
            "Content-Type":
                "application/x-www-form-urlencoded; charset=utf-8"
          },
          body: {
            "event_id": "$eventId",
            "player_id": "$playerId",
            "note": note.trim(),
          },
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(res.body);
    if (data is! Map || data["success"] != true) {
      throw (data is Map
              ? (data["message"] ?? "Не удалось сохранить заметку")
              : "Не удалось сохранить заметку")
          .toString();
    }
  }

 Future<void> _saveCoachRatingForEvent({
  required int eventId,
  required int playerId,
  required int rating,
}) async {
  final normalizedRating = rating.clamp(1, 5);
  final markedBy = await PrefUtils.getUserId() ?? 0;
  final effectiveTeamId = _teamIdForSelectedEvent(eventId);

  if (effectiveTeamId <= 0) {
    throw 'Не найден id команды для сохранения оценки';
  }
  if (markedBy <= 0) {
    throw 'Не найден userId тренера';
  }

  final currentInfo = selectedEventPlayerInfo ?? const <String, dynamic>{};
  final currentStatus = _firstNotEmpty([
    currentInfo['status'],
    currentInfo['attendance_status'],
    selectedEvent?['status'],
    selectedEvent?['attendance_status'],
  ]).trim();
  final currentNote = _firstNotEmpty([
    currentInfo['note'],
    currentInfo['coach_note'],
    currentInfo['trainer_note'],
    selectedEvent?['note'],
    selectedEvent?['coach_note'],
    selectedEvent?['trainer_note'],
  ]).trim();

  try {
    // POST запрос на сохранение
    final res = await http.post(
      Uri.parse('$_apiBase/set_team_attendance.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'},
      body: {
        'team_id': '$effectiveTeamId',
        'event_id': '$eventId',
        'training_id': '$eventId',
        'player_id': '$playerId',
        'user_id': '$playerId',
        'rating': '$normalizedRating',
        'mark': '$normalizedRating',
        'score': '$normalizedRating',
        'coach_rating': '$normalizedRating',
        'trainer_rating': '$normalizedRating',
        'player_rating': '$normalizedRating',
        'coach_player_rating': '$normalizedRating',
        'trainer_player_rating': '$normalizedRating',
        'marked_by': '$markedBy',
        'coach_id': '$markedBy',
        'trainer_id': '$markedBy',
        'created_by': '$markedBy',
        'updated_by': '$markedBy',
        'status': currentStatus.isEmpty ? 'present' : currentStatus,
        if (currentNote.isNotEmpty) 'note': currentNote,
      },
    ).timeout(const Duration(seconds: 14));

    final data = _decodeResponseMap(res.body);
    final isOk = data['success'] == true ||
        data['success'] == 1 ||
        data['success'] == '1' ||
        _asStr(data['status']).toLowerCase() == 'success';

    if (!isOk) {
      throw _apiErrorMessage(data, 'Не удалось сохранить оценку');
    }

    // Дополнительные эндпоинты для совместимости (не блокируем основное сохранение)
    final additionalEndpoints = [
      'save_player_event_rating.php',
      'save_player_training_rating.php',
    ];
    
    for (final endpoint in additionalEndpoints) {
      try {
        await http.post(
          Uri.parse('$_apiBase/$endpoint'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'},
          body: {
            'team_id': '$effectiveTeamId',
            'event_id': '$eventId',
            'training_id': '$eventId',
            'player_id': '$playerId',
            'user_id': '$playerId',
            'rating': '$normalizedRating',
            'mark': '$normalizedRating',
            'score': '$normalizedRating',
            'coach_rating': '$normalizedRating',
            'trainer_rating': '$normalizedRating',
            'player_rating': '$normalizedRating',
            'marked_by': '$markedBy',
          },
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        // Игнорируем ошибки дополнительных эндпоинтов
      }
    }
  } catch (e) {
    rethrow;
  }
}

  
  void _patchCoachRatingLocally({
  required int eventId,
  required int rating,
}) {
  void patchList(List<Map<String, dynamic>> list) {
    for (var i = 0; i < list.length; i++) {
      final id = _trainingRowEventId(list[i]);
      if (id != eventId) continue;
      list[i] = _normalizeAttendanceRow({
        ...list[i],
        'coach_rating': rating,
        'trainer_rating': rating,
        'player_rating': rating,
        'rating': rating,
      });
    }
  }

  patchList(teamEvents);
  patchList(attendanceLog);
  patchList(calendarEvents);

  // Обновление в _trainingCalendarItems кэше не нужно, так как он перестраивается из attendanceLog и teamEvents
  
  // Добавляем в trainingCalendarMonth для календаря
  if (_trainingCalendarMonth != null) {
    // Принудительно обновим календарь при следующем использовании
    _trainingCalendarMonth = DateTime(
      _trainingCalendarMonth!.year,
      _trainingCalendarMonth!.month,
      1,
    );
  }

  if (selectedEvent != null && _trainingRowEventId(selectedEvent!) == eventId) {
    selectedEvent = _normalizeAttendanceRow({
      ...selectedEvent!,
      'coach_rating': rating,
      'trainer_rating': rating,
      'player_rating': rating,
      'rating': rating,
    });
  }

  selectedEventPlayerInfo = _normalizeAttendanceRow({
    ...(selectedEventPlayerInfo ?? const <String, dynamic>{}),
    'event_id': eventId,
    'coach_rating': rating,
    'trainer_rating': rating,
    'player_rating': rating,
    'rating': rating,
  });
}

  Future<void> _openCoachRatingSheet() async {
  final ev = selectedEvent;
  if (ev == null) return;

  final eventId = _trainingRowEventId(ev);
  if (eventId <= 0) return;

  final playerId = await _resolvePlayerId();
  if (playerId <= 0) {
    _showSnack('Не удалось определить player_id');
    return;
  }

  if (_usesCmrRightDetailsPane(context)) {
    _openRightEditor(_CmrRightEditorMode.playerRating);
    return;
  }

  int selectedRating = _normalizeRatingValue(
        _firstRatingValue(selectedEventPlayerInfo, _coachRatingKeys) ??
            _firstRatingValue(ev, _coachRatingKeys),
      ) ??
      0;
  bool saving = false;

  if (!mounted) return;
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> saveRating() async {
            if (saving) return;
            if (selectedRating < 1) {
              _showSnack('Выберите оценку от 1 до 5');
              return;
            }
            setSheetState(() => saving = true);
            try {
              await _saveCoachRatingForEvent(
                eventId: eventId, 
                playerId: playerId, 
                rating: selectedRating
              );
              
              if (!mounted) return;
              
              // Локальное обновление
              setState(() => _patchCoachRatingLocally(eventId: eventId, rating: selectedRating));
              
              // **ВАЖНО: Принудительная перезагрузка данных с сервера**
              await Future.wait([
                _loadPlayerInfoForEvent(eventId),
                _loadAttendanceLog(force: true),
                _loadPlayerTrainingHistory(force: true),
                _loadTeamCalendar(force: true),
              ]);
              
              if (!mounted) return;
              
              // Повторное локальное обновление после загрузки
              setState(() => _patchCoachRatingLocally(eventId: eventId, rating: selectedRating));
              _rebuildOpenSectionSheet();
              
              if (mounted) {
                Navigator.of(ctx).pop(true);
              }
            } catch (e) {
              if (!mounted) return;
              setSheetState(() => saving = false);
              _showSnack(e.toString());
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: _AppColors.cmrBorder, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _AppColors.blueSoft, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.workspace_premium_rounded, color: _AppColors.blue, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Оценка игрока', style: _cmrTitleText(context, mobile: 18, wide: 19, color: _AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text('Оценка тренера за выбранную тренировку', style: _bodyStyle(size: 12, color: _AppColors.textSecondary, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRatingPicker(
                    value: selectedRating,
                    enabled: !saving,
                    onChanged: (v) => setSheetState(() => selectedRating = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : saveRating,
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Сохранить оценку', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (changed == true && mounted) {
    // **ВАЖНО: Еще одна полная перезагрузка после закрытия модального окна**
    await Future.wait([
      _loadPlayerTrainingHistory(force: true),
      _loadAttendanceLog(force: true),
      _loadTeamCalendar(force: true),
    ]);
    _rebuildOpenSectionSheet();
    _showSnack('Оценка сохранена');
  }
}

  Future<void> _openCoachNoteSheet() async {
    final ev = selectedEvent;
    if (ev == null) return;

    final eventId = _asInt(ev["event_id"] ?? ev["id"]);
    if (eventId <= 0) return;

    final playerId = await _resolvePlayerId();
    if (playerId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось определить player_id")),
      );
      return;
    }

    if (_usesCmrRightDetailsPane(context)) {
      _openRightEditor(_CmrRightEditorMode.coachNote);
      return;
    }

    final currentNote = _asStr(selectedEventPlayerInfo?["coach_note"]).trim();
    final c = TextEditingController(text: currentNote);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.sticky_note_2_rounded,
                          color: _primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Заметка тренера к тренировке",
                        style: _titleStyle(size: 16, color: _textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: c,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          "Например: что улучшить, на что обратить внимание, домашнее задание…",
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _saveCoachNoteForEvent(
                          eventId: eventId,
                          playerId: playerId,
                          note: c.text,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        setState(() {
                          selectedEventPlayerInfo = {
                            ...(selectedEventPlayerInfo ?? {}),
                            "coach_note": c.text.trim(),
                          };
                        });

                        await _loadPlayerInfoForEvent(eventId);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Заметка сохранена")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text("Сохранить",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtYmd(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
String? _normalizeImage(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  String url = raw.trim();

  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('sportotekaapp.ru/')) return 'https://$url';
  if (url.startsWith('www.sportotekaapp.ru/')) return 'https://$url';
  if (url.startsWith('/')) return 'https://sportotekaapp.ru$url';
  if (url.startsWith('uploads/')) return 'https://sportotekaapp.ru/$url';

  return 'https://sportotekaapp.ru/uploads/$url';
}

Widget _buildPhotoPreviewTap({
  required Widget child,
  String? imageUrl,
}) {
  if (imageUrl == null || imageUrl.trim().isEmpty) return child;

  return Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _openPlayerPhotoPreview(imageUrl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Color(0xFF667085),
                size: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openPlayerPhotoPreview(String? rawUrl) async {
  final url = _normalizeImage(rawUrl);
  if (url == null || url.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(.88),
    builder: (dialogContext) {
      return GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Material(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        child: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildCircleNetworkImage({
  String? imageUrl,
  required double size,
  double borderWidth = 3,
  Color? borderColor,
  Color? glow,
  required Widget fallback,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: (imageUrl == null || imageUrl.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, _) => Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                ),
              ),
              errorWidget: (context, _, __) => fallback,
            ),
    ),
  );
}
  Future<void> _loadTeamCalendar({bool force = false}) async {
    if (calendarLoading) return;
    if (!force && calendarEvents.isNotEmpty) return;

    setState(() {
      calendarLoading = true;
      calendarError = null;
    });

    try {
      final teamId = _teamId;
      if (teamId <= 0) throw "team_id is required";

      final clubId =
          _asInt(widget.player["club_id"] ?? widget.player["clubId"] ?? 0);

      final now = DateTime.now();
      final monthBase = _trainingCalendarMonth ?? _selectedTrainingDay ?? now;
      final from = _calendarFrom ?? DateTime(monthBase.year, monthBase.month, 1);
      final to = _calendarTo ?? DateTime(monthBase.year, monthBase.month + 1, 0);

      final url = Uri.parse(
        "$_apiBase/get_team_events.php"
        "?team_id=$teamId"
        "&club_id=$clubId"
        "&from=${_fmtYmd(from)}"
        "&to=${_fmtYmd(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = _decodeResponseMap(res.body);

      if (_isBadApiResponse(data)) {
        throw _apiErrorMessage(data, "Ошибка загрузки календаря");
      }

      final raw = _firstList(data, const ["items", "events", "data", "rows"]);
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      list.sort((a, b) {
        final da =
            DateTime.tryParse(_asStr(a["start_at"]).replaceAll(' ', 'T')) ??
                DateTime(1970);
        final db =
            DateTime.tryParse(_asStr(b["start_at"]).replaceAll(' ', 'T')) ??
                DateTime(1970);
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() {
        calendarEvents = list;
        calendarLoading = false;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        calendarLoading = false;
        calendarError = e.toString();
        calendarEvents = [];
      });
      _rebuildOpenSectionSheet();
    }
  }

  List<Map<String, dynamic>> _filteredCalendarEvents() {
    final q = _calendarSearchC.text.trim().toLowerCase();
    if (q.isEmpty) return calendarEvents;

    return calendarEvents.where((e) {
      final t = _asStr(e["title"]).toLowerCase();
      final ty = _asStr(e["type"]).toLowerCase();
      final loc = _asStr(e["location"]).toLowerCase();
      final dt = _asStr(e["start_at"]).toLowerCase();
      return t.contains(q) || ty.contains(q) || loc.contains(q) || dt.contains(q);
    }).toList();
  }

  Future<void> _pickCalendarRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _calendarFrom ?? DateTime(now.year, now.month, 1),
        end: _calendarTo ?? DateTime(now.year, now.month + 1, 0),
      ),
    );

    if (picked == null) return;

    setState(() {
      _calendarFrom =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _calendarTo = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });

    await _loadTeamCalendar(force: true);
  }

  void _clearCalendarRange() async {
    setState(() {
      _calendarFrom = null;
      _calendarTo = null;
    });
    await _loadTeamCalendar(force: true);
  }

  String _calendarRangeText() {
    final from = _calendarFrom;
    final to = _calendarTo;
    if (from == null && to == null) return "Текущий месяц";
    final f = from != null ? DateFormat('dd.MM.yyyy').format(from) : "…";
    final t = to != null ? DateFormat('dd.MM.yyyy').format(to) : "…";
    return "$f — $t";
  }

  String _fmtTime(String raw) {
    if (raw.trim().isEmpty) return "";
    final d = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (d == null) return raw;
    return DateFormat('dd.MM.yyyy • HH:mm').format(d);
  }


  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> _getJsonFlexible(String endpoint, Map<String, String> params) async {
    final uri = Uri.parse('$_apiBase/$endpoint').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final body = res.body.trim();
    if (body.isEmpty || body.startsWith('<')) return null;
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  bool _rowBelongsToCurrentPlayer(Map<String, dynamic> row, int playerId) {
    final playerLikeIds = [
      row['player_id'],
      row['footballer_id'],
      row['athlete_id'],
      row['student_id'],
      row['user_id'],
      row['playerId'],
      row['playerID'],
    ].map((e) => _asInt(e)).where((e) => e > 0).toSet();

    // В отчетах get_match_ttd_report.php поле id часто является id строки отчета,
    // а не id игрока, поэтому не фильтруем по нему, если есть нормальное player_id.
    if (playerLikeIds.isEmpty) return true;
    return playerLikeIds.contains(playerId);
  }

  List<Map<String, dynamic>> _filterTtdRowsForPlayer(List<Map<String, dynamic>> rows, int playerId) {
    return rows.where((row) => _rowBelongsToCurrentPlayer(row, playerId)).toList();
  }

  Future<void> _loadPlayerTtdForMatch(Map<String, dynamic> match) async {
    final matchId = _asInt(match['match_id'] ?? match['id']);
    final playerId = await _resolvePlayerId();

    if (matchId <= 0 || playerId <= 0) {
      if (!mounted) return;
      setState(() {
        selectedTtdMatch = match;
        playerTtdLoading = false;
        playerTtdError = 'Не удалось определить матч или игрока для загрузки ТТД';
        playerTtdMainRows = [];
        playerTtdPassRows = [];
        playerTtdGoalkeeperRows = [];
        playerTtdSummary = {};
      });
      _rebuildOpenSectionSheet();
      return;
    }

    setState(() {
      selectedTtdMatch = match;
      playerTtdLoading = true;
      playerTtdError = null;
      playerTtdMainRows = [];
      playerTtdPassRows = [];
      playerTtdGoalkeeperRows = [];
      playerTtdSummary = {};
    });
    _rebuildOpenSectionSheet();

    try {
      // Важно: используем рабочий API полного отчёта по матчу,
      // а здесь фильтруем строки строго по текущему игроку.
      final reportUri = Uri.parse(
        '$_apiBase/get_match_ttd_report.php',
      ).replace(queryParameters: {'match_id': '$matchId'});

      final reportRes = await http.get(reportUri).timeout(const Duration(seconds: 20));
      Map<String, dynamic>? data;

      if (reportRes.statusCode == 200) {
        final body = reportRes.body.trim();
        if (body.isNotEmpty && !body.startsWith('<')) {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            final ok = map['success'] == true ||
                map['status'] == 'success' ||
                map.containsKey('main_report') ||
                map.containsKey('pass_report') ||
                map.containsKey('goalkeeper_report');
            if (ok) data = map;
          }
        }
      }

      // Запасные старые endpoints оставляем, если на другом сервере отчет называется иначе.
      if (data == null) {
        final params = {
          'match_id': '$matchId',
          'player_id': '$playerId',
          'team_id': '$_teamId',
        };

        for (final endpoint in const [
          'get_player_match_ttd.php',
          'get_match_player_ttd.php',
          'get_player_ttd_by_match.php',
          'get_match_report.php',
          'get_team_match_report.php',
        ]) {
          final result = await _getJsonFlexible(endpoint, params);
          if (result == null) continue;
          final ok = result['success'] == true ||
              result['status'] == 'success' ||
              result.containsKey('rows') ||
              result.containsKey('main') ||
              result.containsKey('main_report') ||
              result.containsKey('mainReportRows');
          if (ok) {
            data = result;
            break;
          }
        }
      }

      if (data == null) {
        final fallbackText = _asStr(match['ttd_text']).trim();
        if (fallbackText.isNotEmpty) {
          data = {
            'success': true,
            'rows': [
              {'metric': 'ТТД тренера', 'value': fallbackText}
            ],
          };
        } else {
          throw 'ТТД по этому игроку и матчу пока не найдены';
        }
      }

      final root = data['data'] is Map ? Map<String, dynamic>.from(data['data']) : data;

      final mainRaw = root['main_report'] ??
          root['mainReportRows'] ??
          root['main_rows'] ??
          root['main'] ??
          root['rows'] ??
          root['ttd'] ??
          [];
      final passRaw = root['pass_report'] ??
          root['passReportRows'] ??
          root['pass_rows'] ??
          root['passes'] ??
          root['pass'] ??
          [];
      final gkRaw = root['goalkeeper_report'] ??
          root['goalkeeperReportRows'] ??
          root['goalkeeper_rows'] ??
          root['goalkeeper'] ??
          root['gk'] ??
          [];
      final totalsRaw = root['player_video_totals'] ?? root['video_totals'] ?? [];
      final episodesRaw = root['episodes'] ?? [];

      final mainRows = _filterTtdRowsForPlayer(_asMapList(mainRaw), playerId);
      final passRows = _filterTtdRowsForPlayer(_asMapList(passRaw), playerId);
      final gkRows = _filterTtdRowsForPlayer(_asMapList(gkRaw), playerId);
      final totalsRows = _filterTtdRowsForPlayer(_asMapList(totalsRaw), playerId);
      final episodeRows = _filterTtdRowsForPlayer(_asMapList(episodesRaw), playerId);

      final summary = <String, dynamic>{};
      if (root['summary'] is Map) {
        summary.addAll(Map<String, dynamic>.from(root['summary']));
      }
      if (totalsRows.isNotEmpty) {
        final totals = totalsRows.first;
        for (final key in ['total', 'ttd_total', 'success_total', 'fail_total', 'effect_percent']) {
          if (totals.containsKey(key)) summary[key] = totals[key];
        }
      }
      if (episodeRows.isNotEmpty) {
        summary['episodes'] = episodeRows.length;
      }

      final hasAnyRows = mainRows.isNotEmpty || passRows.isNotEmpty || gkRows.isNotEmpty;
      if (!hasAnyRows) {
        final fallbackText = _asStr(match['ttd_text']).trim();
        if (fallbackText.isNotEmpty) {
          mainRows.add({'metric': 'ТТД тренера', 'value': fallbackText});
        }
      }

      if (!mounted) return;
      setState(() {
        playerTtdMainRows = mainRows;
        playerTtdPassRows = passRows;
        playerTtdGoalkeeperRows = gkRows;
        playerTtdSummary = summary;
        playerTtdLoading = false;
        playerTtdError = null;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        playerTtdLoading = false;
        playerTtdError = e.toString();
      });
      _rebuildOpenSectionSheet();
    }
  }

 Future<void> _loadMatches({bool force = false}) async {
  if (matchesLoading) return;
  if (!force && matches.isNotEmpty) return;

  setState(() {
    matchesLoading = true;
    matchesError = null;
  });

  try {
    final teamId = _teamId;
    if (teamId <= 0) throw "team_id is required";

    final uri = Uri.parse(
      "$_apiBase/get_team_matches.php?team_id=$teamId",
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw "Ошибка сервера: ${res.statusCode}";
    }

    final body = res.body.trim();
    if (body.isEmpty) {
      throw "Сервер вернул пустой ответ";
    }

    final data = jsonDecode(body);

    if (data is! Map || data["success"] != true) {
      throw (data is Map
              ? (data["message"] ?? "Ошибка загрузки матчей")
              : "Ошибка загрузки матчей")
          .toString();
    }

    final raw = (data["matches"] ?? []) as List;
    final list = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    list.sort((a, b) {
      final da = DateTime.tryParse(
            _asStr(a["match_date"] ?? a["date"] ?? a["created_at"])
                .replaceAll(' ', 'T'),
          ) ??
          DateTime(1970);
      final db = DateTime.tryParse(
            _asStr(b["match_date"] ?? b["date"] ?? b["created_at"])
                .replaceAll(' ', 'T'),
          ) ??
          DateTime(1970);
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      matches = list;
      matchesLoading = false;
    });
    _rebuildOpenSectionSheet();
  } catch (e) {
    if (!mounted) return;
    setState(() {
      matchesLoading = false;
      matchesError = e.toString();
      matches = [];
    });
    _rebuildOpenSectionSheet();
  }
}

  Future<void> _openPrivateChat() async {
    try {
      final myId = await PrefUtils.getUserId() ?? 0;
      final peerId = widget.player['user_id'] as int? ?? 0;

      if (myId <= 0) {
        Get.snackbar("Чат", "Не найден мой user_id",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (peerId <= 0) {
        Get.snackbar("Чат", "Не найден user_id игрока",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (myId == peerId) return;

      final resp = await http.post(
        Uri.parse(_getOrCreatePrivateChatUrl),
        body: {
          'me': myId.toString(),
          'peer_id': peerId.toString(),
        },
      );

      if (resp.statusCode != 200) {
        Get.snackbar("Чат", "Ошибка сервера: ${resp.statusCode}",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final data = jsonDecode(resp.body);
      final ok = (data is Map && data['success'] == true);
      if (!ok) {
        Get.snackbar(
          "Чат",
          (data is Map && data['error'] != null)
              ? data['error'].toString()
              : "Ошибка",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final chatId = int.tryParse('${data['chat_id'] ?? ''}') ?? 0;
      if (chatId <= 0) {
        Get.snackbar("Чат", "Не удалось получить chat_id",
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final chatName =
          (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок")
              .toString();

      if (!mounted) return;
      await _openEmbeddedChatPanel(
        chatId: chatId,
        myId: myId,
        chatName: chatName,
      );
    } catch (e) {
      Get.snackbar("Чат", "Ошибка: $e",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openEmbeddedChatPanel({
    required int chatId,
    required int myId,
    required String chatName,
  }) async {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;

    if (isTablet) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(.28),
        builder: (dialogContext) {
          final size = MediaQuery.of(dialogContext).size;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            backgroundColor: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width >= 1280 ? 1120 : size.width * .94,
                  maxHeight: size.height >= 860 ? 790 : size.height * .90,
                ),
                child: _CmrEmbeddedPanel(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Чат с игроком',
                  subtitle: chatName,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  child: ChatRoomScreen(
                    chatId: chatId,
                    userId: myId,
                    chatName: chatName,
                    embedded: true,
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .97,
          widthFactor: 1,
          child: _CmrEmbeddedPanel(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Чат с игроком',
            subtitle: chatName,
            onClose: () => Navigator.of(sheetContext).pop(),
            child: ChatRoomScreen(
              chatId: chatId,
              userId: myId,
              chatName: chatName,
              embedded: true,
            ),
          ),
        );
      },
    );
  }


  Widget _buildCollapsibleHeaderContent({required double collapseT}) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final isTablet = width >= 720;
    final isSmall = width < 390;

    final photo = _normalizeImage(widget.player["photo"]);
    final fullName = (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок").toString().trim();
    final position = _firstNotEmpty([widget.player["position"], widget.player["player_position"]]);
    final jerseyNumber = _firstNotEmpty([widget.player["jersey_number"], widget.player["number"], widget.player["player_number"]]);
    final club = _playerClub();
    final age = _playerAge();

    final displayName = fullName.isEmpty ? 'Игрок' : fullName;
    final posText = position.isEmpty ? 'Не указано' : position;
    final clubText = club.isEmpty ? 'Клуб не указан' : club;
    final numberText = jerseyNumber.isEmpty || jerseyNumber == '-' ? '—' : '№$jerseyNumber';
    final ageText = age.isEmpty || age == '-' ? '—' : (age.contains('лет') ? age : '$age лет');

    final showDetails = collapseT < 0.70;
    final avatarSize = showDetails
        ? (isTablet ? 96.0 : (isSmall ? 76.0 : 88.0))
        : (isTablet ? 46.0 : 42.0);
    final titleSize = showDetails
        ? (isTablet ? 24.0 : (isSmall ? 18.5 : 20.5))
        : (isTablet ? 16.5 : 15.2);
    final cardRadius = showDetails ? 30.0 : 18.0;
    final horizontal = isTablet ? 24.0 : (isSmall ? 14.0 : 18.0);
    final maxWidth = isTablet ? 1120.0 : double.infinity;

    Widget titleBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: titleSize,
              height: 1.02,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF101828),
              letterSpacing: -0.45,
            ),
          ),
          SizedBox(height: showDetails ? 8 : 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 17, color: Color(0xFF2563EB)),
              SizedBox(width: _isDesktopOrTablet(context) ? 12 : 7),
              Expanded(
                child: Text(
                  clubText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: showDetails ? (isTablet ? 14.2 : 13.0) : 11.5,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
          if (showDetails) ...[
            const SizedBox(height: 6),
            Text(
              posText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: isTablet ? 14.0 : 12.8,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ],
      );
    }

    final headerTop = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCircleNetworkImage(
          imageUrl: photo,
          size: avatarSize,
          borderColor: _AppColors.cmrBorder,
          borderWidth: 2,
          glow: const Color(0xFF101828).withOpacity(0.04),
          fallback: Container(
            color: Colors.white,
            child: Icon(Icons.person_outline_rounded, color: const Color(0xFF178A45), size: avatarSize * 0.42),
          ),
        ),
        SizedBox(width: showDetails ? 16 : 10),
        Expanded(child: titleBlock()),
        const SizedBox(width: 10),
        showDetails ? _buildHeaderEditButtonLight() : _buildSmallEditButton(),
      ],
    );

    final infoRow = Row(
      children: [
        Expanded(child: _buildHeaderInfoTile(icon: Icons.sports_soccer_rounded, label: 'Амплуа', value: posText)),
        const SizedBox(width: 10),
        Expanded(child: _buildHeaderInfoTile(icon: Icons.numbers_rounded, label: 'Номер', value: numberText)),
        const SizedBox(width: 10),
        Expanded(child: _buildHeaderInfoTile(icon: Icons.calendar_month_outlined, label: 'Возраст', value: ageText)),
      ],
    );

    final actionRow = Row(
      children: [
        Expanded(flex: 100, child: _buildHeaderActionButton(icon: Icons.chat_bubble_outline_rounded, label: 'Написать', onTap: _openPrivateChat)),
        const SizedBox(width: 12),
        Expanded(flex: 145, child: _buildHeaderActionButton(icon: Icons.event_available_outlined, label: isSmall ? 'Тренировка' : 'Назначить тренировку', onTap: _assignTraining)),
      ],
    );

    return Container(
      color: Colors.white,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(isTablet ? 22 : 14, 0, isTablet ? 22 : 14, showDetails ? 8 : 6),
            padding: EdgeInsets.fromLTRB(horizontal, showDetails ? (isTablet ? 18 : 14) : 8, horizontal, showDetails ? (isTablet ? 18 : 14) : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: showDetails
                ? (isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 42, child: headerTop),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 58,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                infoRow,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          headerTop,
                          const SizedBox(height: 22),
                          infoRow,
                        ],
                      ))
                : headerTop,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChatIconButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openPrivateChat,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 27),
        ),
      ),
    );
  }

  Widget _buildHeaderEditButtonLight() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openPlayerEditorPanel,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
        ),
      ),
    );
  }

  Widget _buildSmallChatButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openPrivateChat,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB), size: 20),
        ),
      ),
    );
  }


  Widget _buildSmallEditButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openPlayerEditorPanel,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
        ),
      ),
    );
  }

  Widget _buildHeaderInfoTile({required IconData icon, required String label, required String value}) {
    final isPosition = label == 'Амплуа';
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF178A45)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.4, height: 1.05, fontWeight: FontWeight.w700, color: const Color(0xFF6B778A)))),
          ]),
          const SizedBox(height: 10),
          Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: isPosition ? 12.9 : 15.8, height: 1.05, fontWeight: FontWeight.w700, color: const Color(0xFF101828), letterSpacing: -0.2)),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final isLong = label.length > 10;
    final accent = _actionAccent(icon, label);
    final soft = _AppColors.softFor(accent);
    final hint = _actionHint(label);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 58,
          padding: EdgeInsets.symmetric(horizontal: isLong ? 8 : 12),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.78),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: isLong ? 17 : 18),
              ),
              SizedBox(width: isLong ? 6 : 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: accent,
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                          fontSize: isLong ? 12.2 : 13.8,
                          height: 1.05,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================
  // HEADER
  // =============================
  Widget _buildHeader() {
    final photo = _normalizeImage(widget.player["photo"]);
    final fullName =
        (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок")
            .toString()
            .trim();
    final position = _firstNotEmpty([
      widget.player["position"],
      widget.player["player_position"],
    ]);
    final jerseyNumber = _firstNotEmpty([
      widget.player["jersey_number"],
      widget.player["number"],
      widget.player["player_number"],
    ]);
    final club = _playerClub();
    final age = _playerAge();

    final displayName = fullName.isEmpty ? 'Игрок' : fullName;
    final posText = position.isEmpty ? 'Амплуа не указано' : position;
    final clubText = club.isEmpty ? 'Клуб не указан' : club;
    final numberText = jerseyNumber.isEmpty || jerseyNumber == '-'
        ? '—'
        : '№$jerseyNumber';
    final ageText = age.isEmpty || age == '-'
        ? '—'
        : (age.contains('лет') ? age : '$age лет');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            left: -42,
            bottom: -46,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.055),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCircleNetworkImage(
                      imageUrl: photo,
                      size: 76,
                      borderColor: Colors.white,
                      borderWidth: 2.5,
                      glow: Colors.black.withOpacity(0.12),
                      fallback: Container(
                        color: Colors.white.withOpacity(0.18),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18.9,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _buildHeaderMiniBadge(
                                icon: Icons.sports_soccer_outlined,
                                text: posText,
                              ),
                              _buildHeaderMiniBadge(
                                icon: Icons.shield_outlined,
                                text: clubText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderEditButton(),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactInfoChip(
                              icon: Icons.sports_soccer_rounded,
                              label: 'Амплуа',
                              value: posText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactInfoChip(
                              icon: Icons.shield_outlined,
                              label: 'Клуб',
                              value: clubText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactInfoChip(
                              icon: Icons.numbers_rounded,
                              label: 'Номер',
                              value: numberText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactInfoChip(
                              icon: Icons.cake_outlined,
                              label: 'Возраст',
                              value: ageText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderEditButton() {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(
          AppRoutes.editPlayerScreen,
          arguments: widget.player,
        ),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.edit_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMiniBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10.4,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF178A45).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF178A45), size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 10.1,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: label == 'Амплуа' ? 11.6 : 12.2,
                    height: 1.10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF101828),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
  constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF178A45), size: 16),
              SizedBox(width: _isDesktopOrTablet(context) ? 12 : 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF101828),
                    fontSize: label.length > 12 ? 11.0 : 12.0,
                    height: 1.05,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================
  // TABS
  // =============================
  Widget _buildTabBar() {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 1120 : double.infinity),
        child: Container(
          padding: EdgeInsets.fromLTRB(isTablet ? 22 : 16, isTablet ? 18 : 16, isTablet ? 22 : 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_categoryTabs.length, (i) {
                final tab = _categoryTabs[i];
                final isActive = tab.index == _selectedTabIndex;

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        setState(() => _selectedTabIndex = tab.index);
                        _animationController.reset();
                        _animationController.forward();


                        if (tab.index == 4 || tab.index == 52) {
                          await _loadTrainingSectionData(force: true);
                          if (attendanceLog.isEmpty && !attendanceLoading) {
                            await _loadAttendanceLog(force: false);
                          }
                        }

                        if (tab.index == 5 || tab.index == 50) await _loadMatches();

                        if (tab.index == 7) {
                          await _loadPlayerTestingHistory(force: false);
                        }
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16, vertical: isTablet ? 14 : 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isActive ? const Color(0xFF334155) : Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon, color: isActive ? Colors.white : const Color(0xFF334155), size: isTablet ? 20 : 18),
                            const SizedBox(width: 8),
                            Text(
                              tab.title,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.w700,
                                color: isActive ? Colors.white : const Color(0xFF101828),
                                fontSize: isTablet ? 15 : 13.5,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContentByIndex(int index) {
    switch (index) {
      case 0:
        return _buildGeneralTab();
      case 1:
        return _buildFilteredMetricsTab(
          title: 'Физика игрока',
          subtitle: 'Рост, вес, ЧСС, состояние и базовые физические показатели.',
          icon: Icons.health_and_safety_rounded,
          emptyMessage: 'Физические показатели пока не заполнены.',
          filter: (metric) => _metricGroup(_splitMetricLine(metric)['title'] ?? '') == 'Физика',
          fallbackToAll: false,
        );
      case 2:
        return _buildAchievementsTab();
      case 3:
        return _buildMedicalTab();
      case 4:
        return _buildTrainingTab();
      case 54:
        return _buildAssignedTrainingsTab();
      case 5:
        return _buildMatchesTab();
      case 7:
        return _buildTestingHistoryTab();
      case 8:
        return _buildExportTab();
      case 50:
        return _buildPlayerTtdFocusTab();
      case 51:
        return _buildFilteredMetricsTab(
          title: 'Нагрузка игрока',
          subtitle: 'Скорость, рывки, дистанция, выносливость и тренировочный объём.',
          icon: Icons.monitor_heart_rounded,
          emptyMessage: 'Показатели нагрузки пока не заполнены.',
          filter: (metric) => _metricGroup(_splitMetricLine(metric)['title'] ?? '') == 'Нагрузка',
          fallbackToAll: false,
        );
      case 52:
        return _buildPlayerAttendanceFocusTab();
      default:
        return _buildGeneralTab();
    }
  }

  Widget _buildFilteredMetricsTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool Function(String metric) filter,
    required String emptyMessage,
    bool fallbackToAll = false,
  }) {
    final rows = metrics.where(filter).toList();
    final visibleRows = rows.isEmpty && fallbackToAll ? metrics : rows;
    return _buildCmrSectionShell(
      title: title,
      subtitle: subtitle,
      icon: icon,
      stats: [
        _buildCmrMiniStat('Всего', '${visibleRows.length}', icon),
        _buildCmrMiniStat('Тренировки', '${teamEvents.length}', Icons.fitness_center_rounded),
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_soccer_rounded),
        _buildCmrMiniStat('Профиль', '${_profileReadinessPercent()}%', Icons.verified_user_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_chart_rounded, label: 'Добавить', onTap: _showEditMetricsDialog),
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: _refreshCmrProfile, compact: true),
      ],
      children: [
        if (visibleRows.isEmpty)
          _buildEmptyState(icon: icon, message: emptyMessage)
        else ...[
          _buildMetricsCoachSummary(),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 820;
              if (!wide) {
                return Column(
                  children: visibleRows.map((metric) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildMetricCard(metric))).toList(),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleRows.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 4.45,
                ),
                itemBuilder: (_, i) => _buildMetricCard(visibleRows[i]),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerTtdFocusTab() {
    final withTtd = matches.where(_hasMatchTtd).length;
    final withVideo = matches.where(_matchHasVideo).length;
    return _buildCmrSectionShell(
      title: 'ТТД игрока',
      subtitle: 'Календарь матчей, отметки ТТД и быстрый отчёт по выбранной игре.',
      icon: Icons.bar_chart_rounded,
      hideHeader: true,
      stats: [
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_score_outlined),
        _buildCmrMiniStat('С ТТД', '$withTtd', Icons.analytics_outlined),
        _buildCmrMiniStat('Видео', '$withVideo', Icons.play_circle_outline_rounded),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => _loadMatches(force: true), compact: true),
      ],
      children: [
        _buildTtdWorkspacePanel(),
      ],
    );
  }

  Widget _buildTtdWorkspacePanel() {
    final rows = _selectedMatchDay == null
        ? matches
        : matches.where((m) {
            final d = _matchDateOf(m);
            return d != null && _sameDateOnly(d, _selectedMatchDay!);
          }).toList();

    final panelPadding = EdgeInsets.all(MediaQuery.of(context).size.width < 720 ? 12 : 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Календарь ТТД теперь стоит на той же ширине, что и календарь
        // в разделах «Матчи» и «Тестирование»: без дополнительной внешней
        // карточки и лишнего внутреннего отступа вокруг самого календаря.
        _buildTtdCalendar(
          items: matches,
          selectedDay: _selectedMatchDay,
          displayMonth: _matchesCalendarMonth ?? _selectedMatchDay ?? DateTime.now(),
          loading: matchesLoading,
          onMonthChanged: (month) => _safeSetState(() => _matchesCalendarMonth = month),
          onSelect: (day, dayMatches) {
            _safeSetState(() {
              _selectedMatchDay = day;
              _matchesCalendarMonth = DateTime(day.year, day.month, 1);
            });
            if (dayMatches.isNotEmpty) {
              _selectMatchForDetails(Map<String, dynamic>.from(dayMatches.first), loadTtd: true);
            } else {
              _rebuildOpenSectionSheet();
            }
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: panelPadding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTtdMatchesPeriodHeader(rows.length),
              const SizedBox(height: 9),
              if (matchesLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (matchesError != null)
                _buildEmptyState(
                  icon: Icons.error_outline_rounded,
                  message: matchesError!,
                  action: TextButton(onPressed: () => _loadMatches(force: true), child: const Text('Повторить')),
                )
              else if (matches.isEmpty)
                _buildEmptyState(
                  icon: Icons.analytics_outlined,
                  message: 'Матчи с ТТД пока не найдены. После добавления матчей здесь появится календарь отчётов.',
                  action: TextButton(onPressed: () => _loadMatches(force: true), child: const Text('Обновить')),
                )
              else if (rows.isEmpty)
                _buildEmptyState(icon: Icons.event_busy_rounded, message: 'На выбранную дату матчей нет.')
              else
                Column(
                  children: rows.map((m) {
                    final matchId = _asInt(m['match_id'] ?? m['id']);
                    final active = selectedTtdMatch != null &&
                        matchId > 0 &&
                        matchId == _asInt(selectedTtdMatch!['match_id'] ?? selectedTtdMatch!['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildTtdMatchPeriodRow(m, active: active),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTtdMatchesPeriodHeader(int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Матчи за период', style: _titleStyle(size: 14.5, color: _textPrimary)),
              const SizedBox(height: 2),
              Text(
                'Нажмите на матч — подробный отчёт откроется справа',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(size: 11.4, color: _textSecondary, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_rounded, size: 15, color: Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(count == 0 ? 'Все типы' : 'Все типы', style: _bodyStyle(size: 11.2, color: const Color(0xFF475569), weight: FontWeight.w700)),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _calendarLikeCmrPanelSize(Widget child, {double maxWidth = 480}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth;
        final width = math.min(maxWidth, available);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }

  Widget _buildTtdCalendar({
    required List<Map<String, dynamic>> items,
    required DateTime? selectedDay,
    required DateTime displayMonth,
    required void Function(DateTime day, List<Map<String, dynamic>> dayMatches) onSelect,
    ValueChanged<DateTime>? onMonthChanged,
    bool loading = false,
  }) {
    final month = DateTime(displayMonth.year, displayMonth.month, 1);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return _calendarLikeCmrPanelSize(
      Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              _calendarArrow(
                Icons.chevron_left_rounded,
                () => onMonthChanged != null
                    ? onMonthChanged(DateTime(month.year, month.month - 1, 1))
                    : onSelect(DateTime(month.year, month.month - 1, 1), const <Map<String, dynamic>>[]),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('LLLL yyyy', 'ru').format(month), style: _titleStyle(size: 14.5, color: const Color(0xFF101828))),
                      if (loading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                ),
              ),
              _calendarArrow(
                Icons.chevron_right_rounded,
                () => onMonthChanged != null
                    ? onMonthChanged(DateTime(month.year, month.month + 1, 1))
                    : onSelect(DateTime(month.year, month.month + 1, 1), const <Map<String, dynamic>>[]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => Expanded(child: Center(child: Text(d, style: _bodyStyle(size: 10.5, color: const Color(0xFF667085), weight: FontWeight.w700)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: total,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, i) {
              final dayNum = i - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

              final day = DateTime(month.year, month.month, dayNum);
              final dayMatches = items.where((m) {
                final d = _matchDateOf(m);
                return d != null && _sameDateOnly(d, day);
              }).toList();
              final count = dayMatches.length;
              final has = count > 0;
              final selected = selectedDay != null && _sameDateOnly(day, selectedDay);
              final accent = has ? _ttdAccentForMatches(dayMatches) : const Color(0xFFCBD5E1);
final danger = has && accent == _AppColors.error;

final markerColors = dayMatches
    .map((m) => _ttdAccentForMatches([m]))
    .toList();

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(day, dayMatches.map((e) => Map<String, dynamic>.from(e)).toList()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? _AppColors.cmrGreen
                        : has
                            ? (danger ? _AppColors.redSoft : _AppColors.cmrSoft)
                            : _AppColors.cmrSoftPanel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$dayNum', style: TextStyle(color: selected ? Colors.white : const Color(0xFF101828), fontSize: 11.3, fontWeight: FontWeight.w700)),
                          if (has) ...[
                            const SizedBox(width: 3),
                            Container(
                              constraints: const BoxConstraints(minWidth: 14),
                              height: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(color: selected ? Colors.white : accent, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Text('$count', style: TextStyle(color: selected ? _AppColors.cmrGreen : Colors.white, fontSize: 8.2, fontWeight: FontWeight.w700))),
                            ),
                          ],
                        ],
                      ),
                      if (has) ...[
                        const SizedBox(height: 3),
                        _buildCalendarSegmentMarker(markerColors, selected: selected),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTtdMatchPeriodRow(Map<String, dynamic> m, {required bool active}) {
    final matchId = _asInt(m['match_id'] ?? m['id']);
    final opponent = _asStr(m['opponent']).trim().isEmpty ? 'Соперник не указан' : _asStr(m['opponent']).trim();
    final tournament = _asStr(m['competition_name'] ?? m['tournament'] ?? m['type']).trim();
    final dateRaw = _asStr(m['match_date'] ?? m['date'] ?? m['start_at']).trim();
    final date = _formatMatchDate(dateRaw);
    final score = _matchScore(m).trim().isEmpty ? '—' : _matchScore(m).trim();
    final hasTtd = _hasMatchTtd(m);
    final hasVideo = _matchHasVideo(m);
    final ratingText = _matchTtdRatingText(m);
    final resultColor = _matchResultColor(m);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: matchId <= 0 ? null : () => _selectMatchForDetails(m, loadTtd: true),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  children: [
                    Text(date.isEmpty ? '—' : date.split('.').first, style: _titleStyle(size: 15.5, color: _textPrimary)),
                    Text(date.isEmpty ? '' : _monthShortRu(date), style: _bodyStyle(size: 9.4, color: _textSecondary, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.sports_soccer_rounded, color: _AppColors.cmrGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 13.2, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text(tournament.isEmpty ? 'Матч' : tournament, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.7, color: _textSecondary, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _buildTinyTtdBadge(Icons.calendar_month_rounded, hasTtd ? 'ТТД: есть' : 'ТТД: нет', hasTtd ? _AppColors.cmrGreen : _textTertiary),
                    _buildTinyTtdBadge(Icons.play_circle_outline_rounded, hasVideo ? 'Видео: есть' : 'Видео: нет', hasVideo ? _AppColors.cmrGreen : _textTertiary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _AppColors.softFor(resultColor), borderRadius: BorderRadius.circular(13)),
                    child: Text(score, textAlign: TextAlign.center, style: _bodyStyle(size: 12.4, color: resultColor, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  Text('Оценка: ${ratingText.isEmpty ? '—' : ratingText}', style: _bodyStyle(size: 9.8, color: _ttdRatingColor(ratingText), weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTinyTtdBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(999), ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: color),
          const SizedBox(width: 4),
          Text(label, style: _bodyStyle(size: 9.7, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPlayerAttendanceFocusTab() {
    return _buildCmrSectionShell(
      title: 'Посещаемость игрока',
      subtitle: 'Календарь посещений, отметки тренера, опоздания и подробный отчёт по выбранной дате.',
      icon: Icons.calendar_month_rounded,
      hideHeader: true,
      stats: [
        _buildCmrMiniStat('Записей', '${attendanceLog.length}', Icons.fact_check_rounded),
        _buildCmrMiniStat('Посещаемость', '${_attendanceMonthRate()}%', Icons.trending_up_rounded),
        _buildCmrMiniStat('Пропуски', '${_attendanceRowsForMonth().where((x) => _attendanceStatusOf(x) == 'absent').length}', Icons.block_rounded),
        _buildCmrMiniStat('Опоздания', '${_attendanceRowsForMonth().where((x) => _attendanceStatusOf(x) == 'late').length}', Icons.schedule_rounded),
      ],
      actions: [
        _buildCmrActionChip(
          icon: Icons.today_rounded,
          label: 'Сегодня',
          compact: true,
          onTap: () async {
            final now = DateTime.now();
            _safeSetState(() {
              _selectedTrainingDay = DateTime(now.year, now.month, now.day);
              _eventFilterDate = _selectedTrainingDay;
              _trainingCalendarMonth = DateTime(now.year, now.month, 1);
            });
            await _loadTrainingMonth(now, force: true);
          },
        ),
        _buildCmrActionChip(
          icon: Icons.refresh_rounded,
          label: 'Обновить',
          onTap: () => _loadTrainingMonth(_trainingCalendarMonth ?? DateTime.now(), force: true),
          compact: true,
        ),
      ],
      children: [
        _buildAttendanceCalendarPanel(),
        const SizedBox(height: 2),
        _buildAttendanceSubTab(),
        if (!_isWideSplitDetailsMode()) ...[
          const SizedBox(height: 12),
          _buildAttendanceMobileReportCard(),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _attendanceRowsForMonth([DateTime? monthBase]) {
    final base = monthBase ?? _trainingCalendarMonth ?? _selectedTrainingDay ?? DateTime.now();
    final month = DateTime(base.year, base.month, 1);
    final rows = attendanceLog.where((row) {
      final d = _parseEventDate(row);
      return d != null && d.year == month.year && d.month == month.month;
    }).map((e) => _enrichTrainingRecord(Map<String, dynamic>.from(e))).toList();
    rows.sort((a, b) => (_parseEventDate(b) ?? DateTime(1970)).compareTo(_parseEventDate(a) ?? DateTime(1970)));
    return rows;
  }

  List<Map<String, dynamic>> _attendanceRowsForDay(DateTime day) {
    final rows = _attendanceRowsForMonth(day).where((row) {
      final d = _parseEventDate(row);
      return d != null && _sameDateOnly(d, day);
    }).toList();
    rows.sort((a, b) => (_parseEventDate(b) ?? DateTime(1970)).compareTo(_parseEventDate(a) ?? DateTime(1970)));
    return rows;
  }

  bool _isPresentAttendance(Map<String, dynamic> row) {
    final st = _attendanceStatusOf(row);
    return st == 'present' || st == 'individual';
  }

  bool _isNegativeAttendance(Map<String, dynamic> row) {
    final st = _attendanceStatusOf(row);
    return st == 'absent' || st == 'late' || st == 'sick' || st == 'injured' || st == 'trauma';
  }

  int _attendanceMonthRate([DateTime? monthBase]) {
    final rows = _attendanceRowsForMonth(monthBase).where((row) => _attendanceStatusOf(row) != 'dayoff').toList();
    if (rows.isEmpty) return 0;
    final good = rows.where(_isPresentAttendance).length;
    return ((good / rows.length) * 100).round().clamp(0, 100);
  }

  int _attendancePresentStreak() {
    final rows = _attendanceRowsForMonth();
    if (rows.isEmpty) return 0;
    var streak = 0;
    for (final row in rows) {
      final st = _attendanceStatusOf(row);
      if (st == 'dayoff' || st == 'unset') continue;
      if (_isPresentAttendance(row)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _attendanceStatusPriority(String status) {
    switch (status) {
      case 'absent':
      case 'injured':
      case 'trauma':
        return 5;
      case 'late':
      case 'sick':
        return 4;
      case 'present':
      case 'individual':
        return 3;
      case 'dayoff':
        return 2;
      default:
        return 1;
    }
  }

  String _attendanceStageLabel(Map<String, dynamic> row) {
    final direct = _firstNotEmpty([
      row['stage'],
      row['age_group'],
      row['category_code'],
      widget.player['stage'],
      widget.player['age_group'],
      widget.player['team_stage'],
      widget.player['team_name'],
      widget.player['teamName'],
    ]).trim();
    final match = RegExp(r'U\d{1,2}', caseSensitive: false).firstMatch(direct);
    if (match != null) return match.group(0)!.toUpperCase();
    return direct.isEmpty ? 'U13' : direct;
  }

  String _attendanceEventTypeLabel(Map<String, dynamic> row) {
    final raw = _firstNotEmpty([row['type'], row['event_type'], row['training_type'], row['category']]).trim();
    final ru = _ruTrainingType(raw);
    if (ru.isNotEmpty && ru != 'Событие') return ru;
    final title = _firstNotEmpty([row['title'], row['event_title'], row['name']]).toLowerCase();
    if (title.contains('матч')) return 'Матч';
    if (title.contains('тест')) return 'Тестирование';
    return 'Тренировка';
  }

  String _attendanceTrainerName(Map<String, dynamic> row) {
    return _firstNotEmpty([
      row['trainer_name'],
      row['coach_name'],
      row['created_by_name'],
      row['author_name'],
      row['trainer'],
      row['coach'],
    ]).trim();
  }

  int _attendanceLateMinutes(Map<String, dynamic> row) {
    return _asInt(row['late_minutes'] ?? row['late'] ?? row['delay_minutes'] ?? row['minutes_late']);
  }

  String _attendanceTimeText(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = _asStr(row[key]).trim();
      if (raw.isEmpty || raw == 'null' || raw == '-' || raw == '—') continue;
      final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
      if (parsed != null) return DateFormat('HH:mm').format(parsed);
      final m = RegExp(r'\b\d{1,2}:\d{2}\b').firstMatch(raw);
      if (m != null) return m.group(0)!;
      return raw;
    }
    return '—';
  }

  String _attendanceDurationText(Map<String, dynamic> row) {
    final direct = _firstNotEmpty([row['duration'], row['duration_text'], row['training_duration']]).trim();
    if (direct.isNotEmpty) return direct;

    DateTime? parseTime(List<String> keys) {
      for (final key in keys) {
        final raw = _asStr(row[key]).trim();
        if (raw.isEmpty || raw == 'null') continue;
        final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
        if (dt != null) return dt;
      }
      return null;
    }

    final start = parseTime(const ['arrival_time', 'arrived_at', 'check_in', 'time_in', 'started_at', 'start_at']);
    final end = parseTime(const ['leave_time', 'departure_time', 'left_at', 'check_out', 'time_out', 'ended_at', 'end_at']);
    if (start == null || end == null || end.isBefore(start)) return '—';
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours <= 0) return '$minutes мин';
    return '$hours ч ${minutes.toString().padLeft(2, '0')} мин';
  }

  Widget _buildAttendanceCalendarPanel() {
    final monthBase = _trainingCalendarMonth ?? _selectedTrainingDay ?? DateTime.now();
    final month = DateTime(monthBase.year, monthBase.month, 1);
    final items = _attendanceRowsForMonth(month);

    return _buildMarkedCalendar(
      items: items,
      dateOf: _trainingDateOf,
      selectedDay: _selectedTrainingDay,
      displayMonth: month,
      onMonthChanged: (nextMonth) {
        _safeSetState(() {
          _trainingCalendarMonth = DateTime(nextMonth.year, nextMonth.month, 1);
        });
        _loadTrainingMonth(nextMonth, force: true);
      },
      onSelect: (day) {
        _safeSetState(() {
          _selectedTrainingDay = day;
          _eventFilterDate = day;
          _trainingCalendarMonth = DateTime(day.year, day.month, 1);
        });
      },
      loading: attendanceLoading || calendarLoading,
      markerColorOf: _attendanceCalendarItemAccent,
      onDayWithItemsTap: (day, rows) {
        if (rows.isNotEmpty) {
          _selectTrainingForDetails(Map<String, dynamic>.from(rows.first), loadInfo: true);
        }
      },
    );
  }

  Widget _buildAttendanceCalendarGrid(DateTime month) {
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rowsByKey = <String, List<Map<String, dynamic>>>{};
    for (final row in _attendanceRowsForMonth(month)) {
      final d = _parseEventDate(row);
      if (d == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
      rowsByKey.putIfAbsent(key, () => []).add(row);
    }

    return Column(
      children: [
        Row(
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
              .map((d) => Expanded(child: Center(child: Text(d, style: _bodyStyle(size: 11, color: _AppColors.textSecondary, weight: FontWeight.w700)))))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: total,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.35),
          itemBuilder: (context, index) {
            final dayNum = index - leading + 1;
            final day = DateTime(month.year, month.month, dayNum);
            final inMonth = dayNum >= 1 && dayNum <= daysInMonth;
            final showDay = inMonth ? dayNum : DateTime(month.year, month.month, dayNum).day;
            final key = DateFormat('yyyy-MM-dd').format(DateTime(day.year, day.month, day.day));
            final dayRows = inMonth ? (rowsByKey[key] ?? const <Map<String, dynamic>>[]) : const <Map<String, dynamic>>[];
            final has = dayRows.isNotEmpty;
            final selected = _selectedTrainingDay != null && inMonth && _sameDateOnly(day, _selectedTrainingDay!);
            final today = inMonth && _sameDateOnly(day, now);

            String status = has ? _attendanceStatusOf(dayRows.first) : (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday ? 'dayoff' : 'unset');
            for (final row in dayRows) {
              final st = _attendanceStatusOf(row);
              if (_attendanceStatusPriority(st) > _attendanceStatusPriority(status)) status = st;
            }
            final late = dayRows.fold<int>(0, (sum, row) => sum + _attendanceLateMinutes(row));
            final meta = _statusMeta(status, late);
            final fill = selected
                ? _AppColors.cmrGreen
                : has
                    ? _AppColors.softFor(meta.color)
                    : _AppColors.cmrSoftPanel;
            final textColor = selected
                ? Colors.white
                : !inMonth
                    ? _AppColors.textTertiary
                    : (status == 'absent' || status == 'injured' || status == 'trauma' ? _AppColors.error : _AppColors.textPrimary);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: !inMonth
                    ? null
                    : () async {
                        _safeSetState(() {
                          _selectedTrainingDay = DateTime(day.year, day.month, day.day);
                          _eventFilterDate = _selectedTrainingDay;
                          _trainingCalendarMonth = DateTime(day.year, day.month, 1);
                        });
                        if (dayRows.isNotEmpty) await _selectTrainingForDetails(Map<String, dynamic>.from(dayRows.first));
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$showDay', style: _bodyStyle(size: 13.8, color: textColor, weight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      if (has)
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: selected ? Colors.white : meta.color, shape: BoxShape.circle))
                      else
                        Text('—', style: _bodyStyle(size: 11, color: selected ? Colors.white : _AppColors.textTertiary, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _activityLegendDot(const Color(0xFF178A45), 'Присутствовал'),
        _activityLegendDot(const Color(0xFFF59E0B), 'Опоздание'),
        _activityLegendDot(const Color(0xFFEF4444), 'Отсутствовал'),
        _activityLegendDot(const Color(0xFF9CA3AF), 'Выходной'),
      ],
    );
  }

  Widget _buildAttendanceMonthSummaryStrip(DateTime month) {
    final rows = _attendanceRowsForMonth(month);
    final missed = rows.where((x) => _attendanceStatusOf(x) == 'absent').length;
    final late = rows.where((x) => _attendanceStatusOf(x) == 'late').length;
    final rate = _attendanceMonthRate(month);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(18)),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.query_stats_rounded, color: _AppColors.cmrGreen, size: 18),
            const SizedBox(width: 8),
            Text('Посещаемость за месяц: $rate%', style: _bodyStyle(size: 12.8, color: _AppColors.cmrGreen, weight: FontWeight.w700)),
          ]),
          Text('•', style: _bodyStyle(size: 13, color: _AppColors.textSecondary, weight: FontWeight.w700)),
          Text('Пропусков: $missed', style: _bodyStyle(size: 12.3, color: _AppColors.textSecondary, weight: FontWeight.w600)),
          Text('•', style: _bodyStyle(size: 13, color: _AppColors.textSecondary, weight: FontWeight.w700)),
          Text('Опозданий: $late', style: _bodyStyle(size: 12.3, color: _AppColors.textSecondary, weight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.7), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.show_chart_rounded, color: _AppColors.cmrGreen, size: 15),
              const SizedBox(width: 6),
              Text('Статистика месяца', style: _bodyStyle(size: 11.5, color: _AppColors.cmrGreen, weight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachRatingFocusTab() {
    final rated = attendanceLog.where((x) => _firstRatingValue(x, _coachRatingKeys) != null).toList();
    return _buildCmrSectionShell(
      title: 'Оценка тренера',
      subtitle: 'Все тренерские оценки по тренировкам и выбранным событиям без смешивания с самооценкой игрока.',
      icon: Icons.star_rounded,
      stats: [
        _buildCmrMiniStat('Оценок', '${rated.length}', Icons.star_rounded),
        _buildCmrMiniStat('Тренировки', '${attendanceLog.length}', Icons.fitness_center_rounded),
        _buildCmrMiniStat('Самооценка', '${diaryItems.length}', Icons.person_rounded),
        _buildCmrMiniStat('Контроль', 'раздельно', Icons.verified_user_outlined),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => _loadAttendanceLog(force: true), compact: true),
      ],
      children: [
        _buildMarkedCalendar(
          items: attendanceLog,
          dateOf: _parseEventDate,
          selectedDay: _selectedTrainingDay,
          displayMonth: _trainingCalendarMonth ?? _selectedTrainingDay ?? DateTime.now(),
          onMonthChanged: (month) => _safeSetState(() => _trainingCalendarMonth = month),
          onSelect: (d) {
            _safeSetState(() {
              _selectedTrainingDay = d;
              _eventFilterDate = d;
              _trainingCalendarMonth = DateTime(d.year, d.month, 1);
            });
          },
          loading: attendanceLoading,
          markerColorOf: _attendanceCalendarItemAccent,
          onDayWithItemsTap: (day, rows) {
            if (rows.isNotEmpty) _selectTrainingForDetails(Map<String, dynamic>.from(rows.first));
          },
        ),
        const SizedBox(height: 12),
        if (attendanceLoading)
          _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator())))
        else if (rated.isEmpty)
          _buildEmptyState(icon: Icons.star_border_rounded, message: 'Оценки тренера пока не заполнены.')
        else
          _buildTrainingAttendanceCardsList(rated),
      ],
    );
  }

  

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildTabContentByIndex(_selectedTabIndex),
    );
  }

  // =============================
  // ОБЩИЕ
  // =============================
  Widget _buildGeneralTab() {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;
    return ListView(
      padding: EdgeInsets.fromLTRB(isTablet ? 0 : 8, isTablet ? 0 : 8, isTablet ? 0 : 8, 22),
      physics: const BouncingScrollPhysics(),
      children: [
        ..._buildOverviewMainChildren(),
        const SizedBox(height: 14),
        ..._buildOverviewRightChildren(),
      ],
    );
  }


  String _ruTrainingType(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final key = value.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');

    if (key == 'theory' || key.contains('теор')) return 'Теория';
    if (key == 'practice' || key == 'practical' || key.contains('практ')) return 'Практика';
    if (key == 'training' || key == 'train' || key.contains('трен')) return 'Тренировка';
    if (key == 'match' || key == 'game' || key.contains('матч') || key.contains('игр')) return 'Матч';
    if (key == 'meeting' || key == 'meet' || key.contains('собран')) return 'Собрание';
    if (key == 'test' || key == 'testing' || key.contains('тест')) return 'Тестирование';
    if (key == 'fitness' || key.contains('physical') || key.contains('физ')) return 'Физическая подготовка';
    if (key == 'technical' || key.contains('tech') || key.contains('техн')) return 'Техническая подготовка';
    if (key == 'tactical' || key.contains('tactic') || key.contains('такт')) return 'Тактическая подготовка';
    if (key == 'recovery' || key.contains('recover') || key.contains('восстанов')) return 'Восстановление';
    if (key == 'medical' || key.contains('мед')) return 'Медицинское событие';
    if (key == 'individual' || key.contains('индив')) return 'Индивидуальная работа';
    if (key == 'group' || key.contains('групп')) return 'Групповая работа';

    return value;
  }

  String _displayValue(String value) {
    final v = value.trim();
    if (v.isEmpty || v == '-') return 'Не указано';
    return v;
  }

  Widget _buildCharacteristicsGrid(List<_InfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
        final itemWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final empty = item.value.trim().isEmpty || item.value == '-';
            final accent = _AppColors.accentForIcon(item.icon);
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: empty ? const Color(0xFFF6F8FA) : _AppColors.softFor(accent), borderRadius: BorderRadius.circular(14)),
                      child: Icon(item.icon, size: 20, color: empty ? const Color(0xFF98A2B3) : accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.6, height: 1, color: const Color(0xFF667085), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(_displayValue(item.value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 13.5, height: 1.05, color: empty ? const Color(0xFF98A2B3) : const Color(0xFF101828), fontWeight: FontWeight.w600, letterSpacing: -0.15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }


  Widget _buildMainInfoSection() {
    final age = _playerAge();
    final birthDate = _playerBirthDate();
    final nationality = _firstNotEmpty([widget.player["nationality"], widget.player["country"], widget.player["citizenship"]]);
    final position = _firstNotEmpty([widget.player["position"], widget.player["player_position"]]);
    final jerseyNumber = _firstNotEmpty([widget.player["jersey_number"], widget.player["number"], widget.player["player_number"]]);
    final height = _firstNotEmpty([widget.player["height"], widget.player["player_height"]]);
    final weight = _firstNotEmpty([widget.player["weight"], widget.player["player_weight"]]);
    final foot = _firstNotEmpty([widget.player["foot"], widget.player["preferred_foot"]]);
    final items = [
      _InfoItem(icon: Icons.cake_rounded, label: "Возраст", value: age.isNotEmpty ? "$age лет" : "-"),
      _InfoItem(icon: Icons.calendar_today_rounded, label: "Дата рождения", value: birthDate.isNotEmpty ? birthDate : "-"),
      _InfoItem(icon: Icons.flag_rounded, label: "Гражданство", value: nationality.isNotEmpty ? nationality : "-"),
      _InfoItem(icon: Icons.sports_soccer_rounded, label: "Позиция", value: position.isNotEmpty ? position : "-"),
      _InfoItem(icon: Icons.format_list_numbered_rounded, label: "Номер", value: jerseyNumber.isNotEmpty ? "#$jerseyNumber" : "-"),
      _InfoItem(icon: Icons.height_rounded, label: "Рост", value: height.isNotEmpty ? "$height см" : "-"),
      _InfoItem(icon: Icons.monitor_weight_rounded, label: "Вес", value: weight.isNotEmpty ? "$weight кг" : "-"),
      _InfoItem(icon: Icons.directions_run_rounded, label: "Рабочая нога", value: foot.isNotEmpty ? foot : "-"),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24), ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.tune_rounded, color: _AppColors.primaryGreen, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Основные характеристики', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 15.5, height: 1.05, fontWeight: FontWeight.w600, color: const Color(0xFF101828), letterSpacing: -0.25)),
                const SizedBox(height: 4),
                Text('Ключевые данные игрока без лишних вложенных рамок', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.7, height: 1.1, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
              ])),
            ],
          ),
          const SizedBox(height: 14),
          _buildCharacteristicsGrid(items),
        ],
      ),
    );
  }


  Widget _buildClubInfoSection() {
    final club = _playerClub();

    return _buildStyledSectionCard(
      title: "Клубная информация",
      icon: Icons.group_rounded,
      child: _buildInfoGrid([
        _InfoItem(
            icon: Icons.sports_rounded,
            label: "Клуб",
            value: club.isNotEmpty ? club : "-"),
        _InfoItem(
            icon: Icons.date_range_rounded,
            label: "В команде с",
            value: _firstNotEmpty([widget.player["joined_date"]]).isNotEmpty
                ? _firstNotEmpty([widget.player["joined_date"]])
                : "-"),
        _InfoItem(
            icon: Icons.sports_score_rounded,
            label: "Контракт до",
            value: _firstNotEmpty([widget.player["contract_until"]]).isNotEmpty
                ? _firstNotEmpty([widget.player["contract_until"]])
                : "-"),
        _InfoItem(
            icon: Icons.money_rounded,
            label: "Статус",
            value: _firstNotEmpty([widget.player["status"]]).isNotEmpty
                ? _firstNotEmpty([widget.player["status"]])
                : "Активен"),
      ]),
    );
  }

  Widget _buildBioInfoSection() {
    final bio = _firstNotEmpty([widget.player["bio"], widget.player["description"]]);
    if (bio.isEmpty) return const SizedBox();

    return _buildStyledSectionCard(
      title: "Описание игрока",
      icon: Icons.info_outline_rounded,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          bio,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: _design.bodyFontSize,
            height: 1.48,
            color: const Color(0xFF101828),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }


  Widget _buildInfoGrid(List<_InfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final gap = 10.0;
        final itemWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            final accent = _AppColors.accentForIcon(item.icon);
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(14)), child: Icon(item.icon, color: accent, size: 19)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_displayValue(item.value), maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14.4, color: const Color(0xFF101828), weight: FontWeight.w600)),
                  ])),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }


  // =============================
  // УНИВЕРСАЛЬНАЯ КАРТОЧКА СЕКЦИИ
  // =============================
  Widget _buildStyledSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final accent = _AppColors.accentForIcon(icon);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: accent, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 17, color: _AppColors.textPrimary, weight: FontWeight.w600))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _buildCoachWorkspaceOverview() {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;
    final fullName = (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок").toString().trim();
    final position = _firstNotEmpty([widget.player["position"], widget.player["player_position"]]);
    final club = _playerClub();
    final age = _playerAge();
    final readiness = _profileReadinessPercent();

    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isTablet ? 54 : 48,
                height: isTablet ? 54 : 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рабочая карточка игрока',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: isTablet ? 21 : 18,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101828),
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fullName.isEmpty ? 'Сводка для тренера: профиль, тренировки, медкарта, матчи и дневник.' : 'Сводка для тренера по игроку: $fullName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: isTablet ? 13.5 : 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildProfileReadinessBadge(readiness),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 780 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: columns == 4 ? 2.85 : 2.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildOverviewMiniStat(Icons.sports_soccer_rounded, 'Амплуа', position.isEmpty ? 'Не указано' : position),
                  _buildOverviewMiniStat(Icons.cake_rounded, 'Возраст', age.isEmpty ? '—' : '$age лет'),
                  _buildOverviewMiniStat(Icons.shield_outlined, 'Клуб', club.isEmpty ? 'Не указан' : club),
                  _buildOverviewMiniStat(Icons.medical_information_outlined, 'Медкарта', '${medicalRecords.length} записей'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileReadinessBadge(int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$percent%', style: TextStyle(fontFamily: _fontFamily, fontSize: _adaptiveFont(context, mobile: 16, wide: 16.2), height: 1, fontWeight: FontWeight.w700, color: const Color(0xFF178A45))),
          const SizedBox(height: 4),
          Text('заполнено', style: TextStyle(fontFamily: _fontFamily, fontSize: 10.1, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
        ],
      ),
    );
  }

  Widget _buildOverviewMiniStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: const Color(0xFF178A45)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.1, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.2, fontWeight: FontWeight.w700, color: const Color(0xFF101828))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachQuickActionsPanel() {
    return _buildWorkspaceCard(
      title: 'Быстрая работа тренера',
      subtitle: 'Самые частые действия вынесены наверх, чтобы не искать их по вкладкам.',
      icon: Icons.flash_on_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            childAspectRatio: columns == 4 ? 1.55 : 1.33,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildCoachActionTile(Icons.event_available_outlined, 'Назначить\nтренировку', 'создать задание', _assignTraining),
              _buildCoachActionTile(Icons.chat_bubble_outline_rounded, 'Написать\nигроку', 'личный чат', _openPrivateChat),
              _buildCoachActionTile(Icons.show_chart_rounded, 'Открыть\nметрики', '${metrics.length} показателей', () => setState(() => _selectedTabIndex = 1)),
              _buildCoachActionTile(Icons.medical_information_outlined, 'Проверить\nмедкарту', '${medicalRecords.length} записей', () => setState(() => _selectedTabIndex = 3)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoachFocusPanel() {
    final hasMetrics = metrics.isNotEmpty;
    final hasMedical = medicalRecords.isNotEmpty;
    final hasMatches = matches.isNotEmpty;
    final hasDiary = diaryItems.isNotEmpty;

    return _buildWorkspaceCard(
      title: 'Контроль игрока',
      subtitle: 'Что тренеру важно проверить перед тренировкой или матчем.',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          _buildCoachChecklistRow(Icons.show_chart_rounded, 'Спортивные метрики', hasMetrics ? 'Заполнено: ${metrics.length}' : 'Нет показателей', hasMetrics, () => setState(() => _selectedTabIndex = 1)),
          _buildCoachChecklistRow(Icons.medical_information_outlined, 'Медицинские записи', hasMedical ? 'Есть записи: ${medicalRecords.length}' : 'Нет записей', hasMedical, () => setState(() => _selectedTabIndex = 3)),
          _buildCoachChecklistRow(Icons.emoji_events_outlined, 'Матчи игрока', hasMatches ? 'Матчей: ${matches.length}' : 'Нужно загрузить историю', hasMatches, () async { setState(() => _selectedTabIndex = 5); await _loadMatches(); }),
        ],
      ),
    );
  }

  Widget _buildCoachDataReadinessPanel() {
    return _buildWorkspaceCard(
      title: 'Данные для решения',
      subtitle: 'Краткая картина по разделам профиля.',
      icon: Icons.analytics_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 4 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            childAspectRatio: columns == 4 ? 1.62 : 1.48,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildDataCounterTile('Метрики', metrics.length.toString(), Icons.query_stats_rounded, () => setState(() => _selectedTabIndex = 1)),
              _buildDataCounterTile('Медиа', mediaLinks.length.toString(), Icons.perm_media_outlined, () => setState(() => _selectedTabIndex = 2)),
              _buildDataCounterTile('Медкарта', medicalRecords.length.toString(), Icons.health_and_safety_outlined, () => setState(() => _selectedTabIndex = 3)),
              _buildDataCounterTile('Матчи', matches.length.toString(), Icons.sports_score_outlined, () async { setState(() => _selectedTabIndex = 5); await _loadMatches(); }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 24, color: const Color(0xFF178A45)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 15.5, height: 1.05, fontWeight: FontWeight.w700, color: const Color(0xFF101828), letterSpacing: -0.25)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.2, height: 1.32, fontWeight: FontWeight.w700, color: const Color(0xFF667085))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCoachActionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final accent = _actionAccent(icon, title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _AppColors.softFor(accent),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _actionHint(title),
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 9.5, fontWeight: FontWeight.w700, color: accent),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 12.8, height: 1.08, fontWeight: FontWeight.w700, color: const Color(0xFF101828), letterSpacing: -0.15)),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.7, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCoachChecklistRow(IconData icon, String title, String subtitle, bool done, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Icon(icon, size: 21, color: const Color(0xFF178A45))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 12.8, fontWeight: FontWeight.w700, color: const Color(0xFF101828), letterSpacing: -0.1)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF667085))),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(done ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: done ? 22 : 15, color: done ? const Color(0xFF178A45) : const Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDataCounterTile(String label, String value, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, size: 20, color: const Color(0xFF178A45)), const Spacer(), const Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF94A3B8))]),
              const Spacer(),
              Text(value, style: TextStyle(fontFamily: _fontFamily, fontSize: 20.6, height: 1, fontWeight: FontWeight.w700, color: const Color(0xFF101828), letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
            ],
          ),
        ),
      ),
    );
  }


  int _profileReadinessPercent() {
    final checks = <bool>[
      _firstNotEmpty([widget.player["fullName"], widget.player["full_name"]]).isNotEmpty,
      _playerAge().isNotEmpty,
      _firstNotEmpty([widget.player["position"], widget.player["player_position"]]).isNotEmpty,
      _playerClub().isNotEmpty,
      metrics.isNotEmpty,
      medicalRecords.isNotEmpty,
      mediaLinks.isNotEmpty,
      _asStr(widget.player["achievements"]).isNotEmpty,
    ];
    final done = checks.where((e) => e).length;
    return ((done / checks.length) * 100).round().clamp(0, 100);
  }

  // =============================
  // МЕТРИКИ
  // =============================
  // =============================
  // ЕДИНЫЙ CMR-БЛОК ДЛЯ РАЗДЕЛОВ ИГРОКА
  // =============================
  Widget _buildCmrSectionShell({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    List<Widget> actions = const [],
    List<Widget> stats = const [],
    bool compactInSplitMode = true,
    bool hideHeader = false,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    final accent = _AppColors.accentForIcon(icon);
    final horizontal = isMobile ? 8.0 : 0.0;
    final splitMode = compactInSplitMode && _isWideSplitDetailsMode();

    Widget? topSummary;
    if (hideHeader || splitMode) {
      // В режиме ПК/планшета справа уже есть детальная панель, поэтому
      // центральная область должна начинаться сразу с основного инструмента
      // раздела: календаря, списка или карточек, без верхних статистических плиток.
      topSummary = null;
    } else {
      topSummary = Container(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildCmrSectionBanner(title: title, subtitle: subtitle, icon: icon, accent: accent),
          if (stats.isNotEmpty) ...[
            SizedBox(height: isMobile ? 10 : 10),
            Wrap(spacing: isMobile ? 7 : 10, runSpacing: isMobile ? 7 : 10, children: stats),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ]),
      );
    }

    return RefreshIndicator(
      color: _AppColors.cmrGreen,
      onRefresh: _refreshCmrProfile,
      child: ListView(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, isMobile ? 18 : 22),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          if (topSummary != null) ...[
            topSummary,
            SizedBox(height: isMobile ? 12 : 14),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildCmrSectionBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    return Container(
      padding: EdgeInsets.all(isMobile ? 13 : 16),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(isMobile ? 22 : 24)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: isMobile ? 42 : 48, height: isMobile ? 42 : 48, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(isMobile ? 15 : 18)), child: Icon(icon, color: accent, size: isMobile ? 21 : 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: isMobile ? 2 : 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 17.5, wide: 20, color: _AppColors.textPrimary, weight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(subtitle, maxLines: isMobile ? 3 : 2, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 12.2, wide: 13.3, color: _AppColors.textSecondary, weight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _buildCmrMiniStat(String title, String value, IconData icon) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    final splitMode = _isWideSplitDetailsMode();
    final accent = _AppColors.accentForIcon(icon);
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = isMobile
        ? ((screenWidth - 46) / 2).clamp(136.0, 166.0).toDouble()
        : (splitMode ? 118.0 : 150.0);
    final tileHeight = isMobile ? 52.0 : (splitMode ? 88.0 : 78.0);

    return SizedBox(
      width: tileWidth,
      height: tileHeight,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        ),
        child: isMobile
            ? Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 13.5, wide: 13.5, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 9.8, wide: 10.2, color: _AppColors.textSecondary, weight: FontWeight.w700)),
                ])),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, size: 17, color: accent),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_upward_rounded, color: _AppColors.cmrGreen, size: 14),
                  ]),
                  const Spacer(),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 18, wide: 19.5, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 10.4, wide: 11, color: _AppColors.textSecondary, weight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildCmrActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool compact = false,
  }) {
    final accent = primary ? _AppColors.cmrGreen : _actionAccent(icon, label);
    final background = primary ? _AppColors.cmrGreen : accent.withOpacity(.09);
    final foreground = primary ? Colors.white : accent;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12, horizontal: compact ? 12 : 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: compact ? 18 : 20, color: foreground),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontSize: compact ? 12.5 : 13, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }


  Widget _buildCmrEditButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = true,
  }) {
    return _buildCmrActionChip(
      icon: icon,
      label: label,
      onTap: onTap,
      primary: primary,
    );
  }

  Widget _buildCmrCard({required Widget child}) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
      ),
      child: child,
    );
  }

  Widget _buildCmrSoftCard({required Widget child, EdgeInsets? padding}) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
      padding: padding ?? EdgeInsets.all(isMobile ? 13 : 16),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      ),
      child: child,
    );
  }


  // =============================
  // МЕТРИКИ
  // =============================
  Widget _buildMetricsTab() {
    return _buildCmrSectionShell(
      title: 'Метрики игрока',
      subtitle: 'Физика, игровые показатели и индивидуальные данные без перегруженных блоков',
      icon: Icons.query_stats_rounded,
      stats: [
        _buildCmrMiniStat('Показателей', '${metrics.length}', Icons.analytics_outlined),
        _buildCmrMiniStat('Медкарта', '${medicalRecords.length}', Icons.health_and_safety_outlined),
        _buildCmrMiniStat('Тренировки', '${teamEvents.length}', Icons.fitness_center_rounded),
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_soccer_rounded),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_chart_rounded, label: 'Добавить метрику', onTap: _showEditMetricsDialog),
        _buildCmrActionChip(icon: Icons.medical_information_outlined, label: 'Медкарта', onTap: () => setState(() => _selectedTabIndex = 3), compact: true),
      ],
      children: [
        if (metrics.isEmpty)
          _buildEmptyState(icon: Icons.analytics_outlined, message: 'Метрики пока не заполнены')
        else ...[
          _buildMetricsCoachSummary(),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 820;
              if (!wide) {
                return Column(
                  children: metrics
                      .map((metric) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildMetricCard(metric),
                          ))
                      .toList(),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 4.45,
                ),
                itemBuilder: (_, i) => _buildMetricCard(metrics[i]),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMetricsCoachSummary() {
    final mainMetrics = metrics.take(3).map(_splitMetricLine).where((m) => m['title']!.isNotEmpty).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AppColors.softFor(_AppColors.cmrGreen),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.monitor_heart_outlined, color: _AppColors.cmrGreen, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Контроль формы',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrTitleText(context, mobile: 15.4, wide: 16.4, color: const Color(0xFF101828), weight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Ключевые показатели собраны компактно, чтобы тренеру было удобно быстро оценить состояние игрока.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrSubtitleText(context, mobile: 12.2, wide: 12.8, color: const Color(0xFF667085), weight: FontWeight.w700),
                ),
                if (mainMetrics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mainMetrics.map((m) {
                      final title = m['title'] ?? '';
                      final value = m['value'] ?? '';
                      final accent = _metricAccent(title);
                      return _buildMetricMetaPill(
                        _metricIcon(title),
                        value.isEmpty ? title : '$title: $value',
                        accent,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String metric) {
    final parsed = _splitMetricLine(metric);
    final rawTitle = parsed['title']?.trim() ?? '';
    final rawValue = parsed['value']?.trim() ?? '';
    final title = rawTitle.isEmpty ? 'Показатель' : rawTitle;
    final value = rawValue.isEmpty ? 'Не указано' : rawValue;
    final accent = _metricAccent(title);
    final icon = _metricIcon(title);
    final group = _metricGroup(title);
    final selected = _selectedMetricForDetails == metric;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          setState(() => _selectedMetricForDetails = metric);
          _rebuildOpenSectionSheet();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? _AppColors.cmrSoft : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : _AppColors.softFor(accent),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _cmrSubtitleText(context, mobile: 12.0, wide: 12.6, color: const Color(0xFF667085), weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricMetaPill(_metricGroupIcon(group), group, accent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 17.0, wide: 17.6, color: const Color(0xFF101828), weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: accent, size: 20),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildMetricMetaPill(IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(size: 11.2, color: accent, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Color _metricAccent(String title) {
    final t = title.toLowerCase();
    if (t.contains('рост') || t.contains('вес') || t.contains('пульс') || t.contains('чсс') || t.contains('давлен')) return _AppColors.cmrGreen;
    if (t.contains('скор') || t.contains('рыв') || t.contains('спринт') || t.contains('дистанц') || t.contains('выносл')) return _AppColors.blue;
    if (t.contains('гол') || t.contains('пас') || t.contains('передач') || t.contains('удар') || t.contains('матч')) return _AppColors.orange;
    if (t.contains('оцен') || t.contains('дисцип') || t.contains('готов') || t.contains('форм')) return _AppColors.blue;
    return _AppColors.cmrGreen;
  }

  IconData _metricIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('рост')) return Icons.height_rounded;
    if (t.contains('вес')) return Icons.monitor_weight_outlined;
    if (t.contains('пульс') || t.contains('чсс') || t.contains('давлен')) return Icons.monitor_heart_outlined;
    if (t.contains('скор') || t.contains('рыв') || t.contains('спринт')) return Icons.speed_rounded;
    if (t.contains('дистанц') || t.contains('выносл')) return Icons.directions_run_rounded;
    if (t.contains('гол')) return Icons.sports_soccer_rounded;
    if (t.contains('пас') || t.contains('передач')) return Icons.compare_arrows_rounded;
    if (t.contains('удар')) return Icons.sports_score_rounded;
    if (t.contains('оцен') || t.contains('форм') || t.contains('готов')) return Icons.verified_rounded;
    return Icons.trending_up_rounded;
  }

  String _metricGroup(String title) {
    final t = title.toLowerCase();
    if (t.contains('рост') || t.contains('вес') || t.contains('пульс') || t.contains('чсс') || t.contains('давлен')) return 'Физика';
    if (t.contains('скор') || t.contains('рыв') || t.contains('спринт') || t.contains('дистанц') || t.contains('выносл')) return 'Нагрузка';
    if (t.contains('гол') || t.contains('пас') || t.contains('передач') || t.contains('удар') || t.contains('матч')) return 'Игра';
    if (t.contains('оцен') || t.contains('дисцип') || t.contains('готов') || t.contains('форм')) return 'Контроль';
    return 'Профиль';
  }

  IconData _metricGroupIcon(String group) {
    switch (group) {
      case 'Физика':
        return Icons.accessibility_new_rounded;
      case 'Нагрузка':
        return Icons.bolt_rounded;
      case 'Игра':
        return Icons.sports_soccer_rounded;
      case 'Контроль':
        return Icons.verified_rounded;
      default:
        return Icons.badge_outlined;
    }
  }

  // =============================
  // ДОСТИЖЕНИЯ И МЕДИА
  // =============================
  Widget _buildAchievementsTab() {
    final achievementsText = _asStr(widget.player['achievements']).trim();
    return _buildCmrSectionShell(
      title: 'Достижения и медиа',
      subtitle: 'Награды, сильные стороны и материалы для портфолио игрока',
      icon: Icons.military_tech_rounded,
      stats: [
        _buildCmrMiniStat('Достижения', achievementsText.isEmpty ? '0' : 'Есть', Icons.emoji_events_outlined),
        _buildCmrMiniStat('Медиа', '${mediaLinks.length}', Icons.collections_outlined),
        _buildCmrMiniStat('Профиль', '${_profileReadinessPercent()}%', Icons.verified_user_outlined),
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_score_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.emoji_events_rounded, label: 'Достижение', onTap: _showEditAchievementsDialog),
        _buildCmrActionChip(icon: Icons.add_photo_alternate_outlined, label: 'Медиа', onTap: _showAddMediaDialog, compact: true),
      ],
      children: [
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Ключевые достижения', style: _titleStyle(size: 16, color: const Color(0xFF101828)))),
              ]),
              const SizedBox(height: 10),
              Text(
                achievementsText.isEmpty ? 'Достижения пока не заполнены. Тренер сможет фиксировать награды, турниры, вызовы, MVP и важные игровые события.' : achievementsText,
                style: _bodyStyle(size: 13.5, color: const Color(0xFF475569), weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (mediaLinks.isEmpty)
          _buildEmptyState(icon: Icons.photo_camera_back_rounded, message: 'Медиа материалы пока не добавлены')
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 720;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mediaLinks.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.18,
                ),
                itemBuilder: (_, i) => _buildMediaItem(mediaLinks[i]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMediaItem(String url) {
    final lower = url.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
    final isVideo = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v');
    final norm = _normalizeImage(url) ?? url;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (_usesCmrRightDetailsPane(context)) {
            setState(() => _selectedMediaForDetails = url);
            _rebuildOpenSectionSheet();
            return;
          }
          launchUrl(Uri.parse(norm), mode: LaunchMode.externalApplication);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            image: isImage ? DecorationImage(image: NetworkImage(norm), fit: BoxFit.cover) : null,
          ),
          child: Stack(
            children: [
              if (!isImage)
                Center(child: Icon(isVideo ? Icons.play_circle_fill_rounded : Icons.attach_file_rounded, size: 38, color: const Color(0xFF178A45))),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(isImage ? 0.42 : 0.06), borderRadius: BorderRadius.circular(999)),
                  child: Text(isVideo ? 'Видео' : isImage ? 'Фото' : 'Файл', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.6, fontWeight: FontWeight.w700, color: isImage ? Colors.white : const Color(0xFF178A45))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================
  // МЕДКАРТА
  // =============================
  Widget _buildMedicalTab() {
    if (isLoading) return Center(child: CircularProgressIndicator(color: _primary));

    final injuries = medicalRecords.where((e) => _asStr(e['type']).toLowerCase().contains('трав')).length;
    final checks = medicalRecords.where((e) => _asStr(e['type']).toLowerCase().contains('осмотр')).length;

    return _buildCmrSectionShell(
      title: 'Медкарта',
      subtitle: 'Медицинские записи, допуски, травмы и документы игрока',
      icon: Icons.medical_information_rounded,
      stats: [
        _buildCmrMiniStat('Записей', '${medicalRecords.length}', Icons.folder_copy_outlined),
        _buildCmrMiniStat('Осмотры', '$checks', Icons.health_and_safety_outlined),
        _buildCmrMiniStat('Травмы', '$injuries', Icons.healing_outlined),
        _buildCmrMiniStat('Файлы', '${medicalRecords.where((e) => _asStr(e['file_url']).isNotEmpty).length}', Icons.attach_file_rounded),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_rounded, label: 'Добавить запись', onTap: _showAddMedicalRecordDialog),
      ],
      children: [
        if (medicalRecords.isEmpty)
          _buildEmptyState(icon: Icons.medical_services_rounded, message: 'Медицинских записей пока нет')
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 820;
              if (!wide) {
                return Column(
                  children: medicalRecords.map(_buildMedicalRecordCard).toList(),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: medicalRecords.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.25,
                ),
                itemBuilder: (_, i) => _buildMedicalRecordCard(medicalRecords[i]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAddButton() {
    return _buildCmrEditButton(icon: Icons.add_rounded, label: 'Запись', onTap: _showAddMedicalRecordDialog);
  }

  Color _medicalAccent(String type) {
    final t = type.toLowerCase();
    if (t.contains('трав')) return _AppColors.error;
    if (t.contains('вакцин')) return _AppColors.blue;
    if (t.contains('справ') || t.contains('допуск')) return _AppColors.cmrGreen;
    if (t.contains('осмотр')) return _AppColors.cmrGreen;
    return _AppColors.cmrGreen;
  }

  IconData _medicalIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('трав')) return Icons.healing_rounded;
    if (t.contains('вакцин')) return Icons.local_hospital_rounded;
    if (t.contains('справ') || t.contains('допуск')) return Icons.medical_services_rounded;
    if (t.contains('осмотр')) return Icons.health_and_safety_rounded;
    return Icons.medical_information_rounded;
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
    final type = _asStr(record['type']).isEmpty ? 'Запись' : _asStr(record['type']);
    final title = _asStr(record['title']).isEmpty ? 'Без названия' : _asStr(record['title']);
    final value = _asStr(record['value']);
    final comment = _asStr(record['comment']);
    final date = _asStr(record['date']).isEmpty ? 'Дата не указана' : _asStr(record['date']);
    final fileUrl = _asStr(record['file_url']);
    final accent = _medicalAccent('$type $title $value');
    final selected = identical(_selectedMedicalRecordForDetails, record) ||
        (_selectedMedicalRecordForDetails != null &&
            _asStr(_selectedMedicalRecordForDetails!['id']) == _asStr(record['id']) &&
            _asStr(record['id']).isNotEmpty);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          setState(() => _selectedMedicalRecordForDetails = Map<String, dynamic>.from(record));
          _rebuildOpenSectionSheet();
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : _AppColors.softFor(accent),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_medicalIcon('$type $title $value'), color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _cmrSubtitleText(context, mobile: 12.0, wide: 12.6, color: const Color(0xFF667085), weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _cmrTitleText(context, mobile: 17.0, wide: 17.4, color: const Color(0xFF101828), weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallCardEditButton(
                    label: 'Изм.',
                    icon: Icons.edit_rounded,
                    onTap: () => _showEditMedicalRecordDialog(record),
                  ),
                ],
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(.75) : _AppColors.cmrSoftPanel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _cmrBodyText(context, mobile: 13.2, wide: 13.4, color: const Color(0xFF344054), weight: FontWeight.w600),
                  ),
                ),
              ],
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: selected ? Colors.white : _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notes_rounded, size: 15, color: Color(0xFF667085)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _cmrBodyText(context, mobile: 12.4, wide: 12.8, color: const Color(0xFF667085), weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildMedicalMetaPill(Icons.calendar_today_rounded, date, const Color(0xFF667085)),
                  if (fileUrl.isNotEmpty)
                    _buildMedicalMetaPill(
                      Icons.attach_file_rounded,
                      'Файл',
                      _AppColors.cmrGreen,
                      onTap: () {
                        final fullUrl = fileUrl.startsWith('http') ? fileUrl : '$_apiBase/../uploads/medical/$fileUrl';
                        launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
                      },
                    ),
                  if (selected) _buildMedicalMetaPill(Icons.check_circle_rounded, 'Выбрано', accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalMetaPill(IconData icon, String label, Color accent, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(size: 11.8, color: accent, weight: FontWeight.w700),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );
  }


  // =============================
  // ТРЕНИРОВКИ
  // =============================
  Widget _buildTrainingTab() {
    final filteredCount = _filteredEvents().length;

    return _buildCmrSectionShell(
      title: 'Тренировки',
      subtitle: 'Профессиональный журнал: календарь, посещаемость, оценки и заметки игрока',
      icon: Icons.sports_soccer_rounded,
      stats: [
        _buildCmrMiniStat('События', '${_trainingCalendarItems().length}', Icons.event_note_outlined),
        _buildCmrMiniStat('Показано', '$filteredCount', Icons.filter_alt_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_task_rounded, label: 'Назначить', onTap: _assignTraining),
        _buildCmrActionChip(
          icon: Icons.refresh_rounded,
          label: 'Обновить',
          compact: true,
          onTap: () async {
            await _loadPlayerTrainingHistory(force: true);
            _rebuildOpenSectionSheet();
          },
        ),
      ],
      children: [
        _buildTrainingCalendarPanel(),
        const SizedBox(height: 12),
        if (_isWideSplitDetailsMode())
          _buildTrainingSplitSelector()
        else
          _buildEventsSubTab(),
      ],
    );
  }

  Widget _buildAssignedTrainingsTab() {
    final filteredCount = _filteredCalendarEvents().length;

    return _buildCmrSectionShell(
      title: 'Назначенные тренировки',
      subtitle: 'Личные тренировки и индивидуальные задания игрока вынесены отдельно от общего журнала',
      icon: Icons.assignment_turned_in_rounded,
      stats: [
        _buildCmrMiniStat('Личные', '${calendarEvents.length}', Icons.person_pin_circle_outlined),
        _buildCmrMiniStat('Показано', '$filteredCount', Icons.filter_alt_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_task_rounded, label: 'Назначить', onTap: _assignTraining),
        _buildCmrActionChip(
          icon: Icons.refresh_rounded,
          label: 'Обновить',
          compact: true,
          onTap: () async {
            await _loadTeamCalendar(force: true);
            _rebuildOpenSectionSheet();
          },
        ),
      ],
      children: [
        _buildIndividualSubTab(),
      ],
    );
  }

  Widget _buildTrainingCalendarPanel() {
    final splitMode = _isWideSplitDetailsMode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!splitMode)
          _buildInlineCalendarHeader(
            title: 'Календарь тренировок',
            subtitle: 'Даты с тренировками отмечены. Выбор даты фильтрует список ниже.',
            expanded: _trainingCalendarExpanded,
            onToggle: () {
              _safeSetState(() => _trainingCalendarExpanded = !_trainingCalendarExpanded);
              _rebuildOpenSectionSheet();
            },
          ),
        if (splitMode || _trainingCalendarExpanded) ...[
          if (!splitMode) const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: _trainingCalendarItems(),
            dateOf: _trainingDateOf,
            selectedDay: _selectedTrainingDay,
            displayMonth: _trainingCalendarMonth ?? _selectedTrainingDay ?? DateTime.now(),
            onMonthChanged: (month) async {
              _safeSetState(() => _trainingCalendarMonth = month);
              await _loadTrainingMonth(month, force: true);
              _rebuildOpenSectionSheet();
            },
            onSelect: (d) {
              _safeSetState(() {
                _selectedTrainingDay = d;
                _trainingCalendarMonth = DateTime(d.year, d.month, 1);
                _eventFilterDate = d;
                selectedEvent = null;
                selectedEventPlayerInfo = null;
              });
              _rebuildOpenSectionSheet();
            },
            loading: eventsLoading || attendanceLoading || calendarLoading,
            markerColorOf: _trainingCalendarItemAccent,
            onDayWithItemsTap: (day, dayItems) {
              if (_usesCmrRightDetailsPane(context)) {
                if (dayItems.isNotEmpty) {
                  _selectTrainingForDetails(Map<String, dynamic>.from(dayItems.first));
                }
                return;
              }
              _showTrainingDayDetailsSheet(day, dayItems);
            },
          ),
          const SizedBox(height: 8),
          _buildTrainingCalendarLegend(),
        ],
        if (_selectedTrainingDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(
            date: _selectedTrainingDay!,
            label: 'Показаны тренировки за дату',
            onClear: () async {
              _safeSetState(() {
                _selectedTrainingDay = null;
                _eventFilterDate = null;
                selectedEvent = null;
                selectedEventPlayerInfo = null;
              });
              await _loadPlayerTrainingHistory(force: true);
              await _loadAttendanceLog(force: true);
              _rebuildOpenSectionSheet();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTrainingCalendarLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _activityLegendDot(_AppColors.cmrGreen, 'общая'),
        _activityLegendDot(_AppColors.orange, 'физика'),
        _activityLegendDot(const Color(0xFF8B5CF6), 'тактика'),
        _activityLegendDot(const Color(0xFF0EA5E9), 'техника'),
        _activityLegendDot(_AppColors.blue, 'игра'),
        _activityLegendDot(_AppColors.error, 'проблема'),
      ],
    );
  }

  Widget _buildTrainingMetaPill(IconData icon, String label, Color accent, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 10.8,
                height: 1.05,
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );
  }

  IconData _trainingTypeIcon(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('матч') || t.contains('игр') || t.contains('match')) return Icons.sports_soccer_rounded;
    if (t.contains('такт')) return Icons.account_tree_rounded;
    if (t.contains('физ') || t.contains('зал')) return Icons.fitness_center_rounded;
    if (t.contains('инд')) return Icons.person_pin_circle_rounded;
    return Icons.event_note_rounded;
  }

  Color _trainingTypeAccent(String raw) {
    final t = raw.toLowerCase().trim();

    // Цвета синхронизированы с календарём команды:
    // тренировка, официальный матч, товарищеский матч, теория, зал/физика, выходной.
    if (t.contains('league_match') ||
        t.contains('league-match') ||
        t.contains('official_match') ||
        t.contains('official-match') ||
        t.contains('official') ||
        t.contains('официаль') ||
        t.contains('чемпион') ||
        t.contains('турнир') ||
        t.contains('соревн') ||
        t.contains('матч')) {
      return const Color(0xFF2563EB);
    }

    if (t.contains('friendly_match') ||
        t.contains('friendly-match') ||
        t.contains('friendly') ||
        t.contains('товар') ||
        t.contains('контроль')) {
      return const Color(0xFF0EA5E9);
    }

    if (t.contains('theory') ||
        t.contains('теор') ||
        t.contains('тактик') ||
        t.contains('разбор') ||
        t.contains('видео')) {
      return const Color(0xFF8B5CF6);
    }

    if (t.contains('gym') ||
        t.contains('зал') ||
        t.contains('физ') ||
        t.contains('сил') ||
        t.contains('скор') ||
        t.contains('вынос') ||
        t.contains('офп') ||
        t.contains('сфп')) {
      return const Color(0xFFF59E0B);
    }

    if (t.contains('day_off') ||
        t.contains('day-off') ||
        t.contains('rest') ||
        t.contains('выход') ||
        t.contains('отдых')) {
      return const Color(0xFF94A3B8);
    }

    if (t.contains('training') ||
        t.contains('train') ||
        t.contains('трен') ||
        t.contains('занят')) {
      return const Color(0xFF1F7A4D);
    }

    // Неизвестное событие не красим в зелёный, чтобы не было ложных тренировок.
    return const Color(0xFF64748B);
  }


  String _eventDateText() {
    if (_eventFilterDate == null) return "Любая дата";
    return DateFormat('dd.MM.yyyy').format(_eventFilterDate!);
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final initial = _eventFilterDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;

    setState(() {
      _eventFilterDate = DateTime(picked.year, picked.month, picked.day);
      _selectedTrainingDay = _eventFilterDate;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });

    await _loadPlayerTrainingHistory(force: true);
  }

  void _clearEventDate() async {
    setState(() {
      _eventFilterDate = null;
      _selectedTrainingDay = null;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });
    await _loadPlayerTrainingHistory(force: true);
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final q = _eventSearchC.text.trim().toLowerCase();
    final selectedDate = _selectedTrainingDay ?? _eventFilterDate;

    final source = _dedupeAndEnrichTrainingRows(teamEvents);

    return source.where((e) {
      final title = _asStr(e["title"]).toLowerCase();
      final date = _asStr(e["date"] ?? e["start_at"] ?? e["day"]).toLowerCase();

      final okQ = q.isEmpty ? true : (title.contains(q) || date.contains(q));
      final d = _parseEventDate(e);
      final okD = selectedDate == null
          ? true
          : (d != null && _sameDateOnly(d, selectedDate));

      return okQ && okD;
    }).toList();
  }

  List<Widget> _buildEventsGroupedByDate(List<Map<String, dynamic>> list) {
    final sorted = _dedupeAndEnrichTrainingRows(list);
    sorted.sort((a, b) {
      final da = _parseEventDate(a) ?? DateTime(1970);
      final db = _parseEventDate(b) ?? DateTime(1970);
      return db.compareTo(da);
    });

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in sorted) {
      final k = _eventGroupKey(e);
      groups.putIfAbsent(k, () => []).add(e);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a) ?? DateTime(1970);
        final db = DateTime.tryParse(b) ?? DateTime(1970);
        return db.compareTo(da);
      });

    final out = <Widget>[];
    for (final k in keys) {
      out.add(_buildTrainingDateHeader(_eventGroupTitle(k), groups[k]!.length));
      out.add(_buildTrainingEventsGrid(groups[k]!));
    }
    return out;
  }

  Widget _buildTrainingDateHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cmrTitleText(context, mobile: 13.6, wide: 15.0, color: const Color(0xFF101828), weight: FontWeight.w700),
            ),
          ),
          _buildTrainingMetaPill(Icons.event_note_outlined, '$count', _AppColors.cmrGreen),
        ],
      ),
    );
  }

  Widget _buildTrainingEventsGrid(List<Map<String, dynamic>> rows) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final columns = c.maxWidth >= 1160 ? 3 : (wide ? 2 : 1);
        final gap = wide ? 12.0 : 10.0;
        final itemWidth = columns == 1 ? c.maxWidth : (c.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: rows
              .map(
                (e) => SizedBox(
                  width: itemWidth,
                  child: _buildTrainingEventCard(e, compact: !wide),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTrainingEventCard(Map<String, dynamic> raw, {required bool compact}) {
    final e = _enrichTrainingRecord(raw);
    final id = _asInt(e['event_id'] ?? e['id']);
    final dateRaw = _anyDateStr(e);
    final title = _firstNotEmpty([e['title'], e['event_title'], e['name']]).trim();
    final type = _firstNotEmpty([e['type'], e['training_type'], e['category']]).trim();
    final typeLabel = _ruTrainingType(type);
    final description = _firstNotEmpty([e['description'], e['body'], e['details']]).trim();
    final status = _attendanceStatusOf(e);
    final lateMin = _asInt(e['late_minutes'] ?? e['late']);
    final meta = _statusMeta(status, lateMin);
    final playerRating = _firstRatingValue(e, _playerRatingKeys);
    final coachRating = _firstRatingValue(e, _coachRatingKeys);
    final active = selectedEvent != null && _asInt(selectedEvent?['event_id'] ?? selectedEvent?['id']) == id;
    final accent = _trainingTypeAccent(typeLabel.isEmpty ? title : typeLabel);

    Future<void> openDetails({bool note = false, bool rating = false}) async {
      setState(() {
        selectedEvent = e;
        selectedEventPlayerInfo = null;
        final d = _parseEventDate(e);
        if (d != null) {
          _selectedTrainingDay = DateTime(d.year, d.month, d.day);
          _eventFilterDate = _selectedTrainingDay;
        }
      });
      _rebuildOpenSectionSheet();
      if (id > 0) await _loadPlayerInfoForEvent(id);
      if (note && mounted) await _openCoachNoteSheet();
      if (rating && mounted) await _openCoachRatingSheet();
      _rebuildOpenSectionSheet();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openDetails(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(compact ? 13 : 15),
          decoration: BoxDecoration(
            color: active ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : _AppColors.softFor(accent),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(_trainingTypeIcon(typeLabel), color: accent, size: compact ? 20 : 22),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Тренировка' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _cmrTitleText(context, mobile: 14.6, wide: 15.6, color: _AppColors.textPrimary, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [if (dateRaw.isNotEmpty) dateRaw, if (typeLabel.isNotEmpty) typeLabel].join(' • ').isEmpty
                              ? 'Дата не указана'
                              : [if (dateRaw.isNotEmpty) dateRaw, if (typeLabel.isNotEmpty) typeLabel].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _cmrSubtitleText(context, mobile: 11.4, wide: 12.2, color: _AppColors.textSecondary, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 17),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _buildTrainingMetaPill(meta.icon, meta.text, meta.color),
                  _buildTrainingMetaPill(Icons.star_rounded, playerRating == null ? 'Игрок —' : 'Игрок ${_asInt(playerRating)}/5', _trainingRatingAccent(playerRating)),
                  _buildTrainingMetaPill(Icons.workspace_premium_rounded, coachRating == null ? 'Тренер —' : 'Тренер ${_asInt(coachRating)}/5', _trainingRatingAccent(coachRating)),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrBodyText(context, mobile: 11.7, wide: 12.2, color: const Color(0xFF475569), weight: FontWeight.w700, height: 1.28),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _compactActionButton(
                    icon: Icons.visibility_rounded,
                    label: 'Открыть',
                    compact: true,
                    onTap: id <= 0 ? null : () => openDetails(),
                  ),
                  _compactActionButton(
                    icon: Icons.star_rounded,
                    label: 'Оценка',
                    compact: true,
                    onTap: id <= 0 ? null : () => openDetails(rating: true),
                  ),
                  _compactActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Заметка',
                    compact: true,
                    onTap: id <= 0 ? null : () => openDetails(note: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showTrainingDayDetailsSheet(DateTime day, List<Map<String, dynamic>> rawItems) async {
    if (!diaryLoading && diaryItems.isEmpty) {
      await _loadDiary();
    }

    final rows = _dedupeAndEnrichTrainingRows(
      rawItems.map((x) => Map<String, dynamic>.from(x)),
    ).where((x) {
      final d = _parseEventDate(x);
      return d != null && _sameDateOnly(d, day);
    }).toList();

    final playerId = await _resolvePlayerId();
    if (playerId > 0) {
      for (var i = 0; i < rows.length; i++) {
        final eventId = _trainingRowEventId(rows[i]);
        if (eventId <= 0) continue;
        final exact = await _fetchTeamAttendanceInfoForEvent(
          eventId: eventId,
          playerId: playerId,
        );
        if (exact == null) continue;
        _mergeTrainingCandidate(rows[i], exact);
        _mergeDiaryFallback(rows[i]);
        rows[i] = _normalizeAttendanceRow(rows[i]);
      }
    }

    if (!mounted || rows.isEmpty) return;

    if (_usesCmrRightDetailsPane(context)) {
      await _selectTrainingForDetails(rows.first, loadInfo: true);
      return;
    }

    setState(() {
      _selectedTrainingDay = DateTime(day.year, day.month, day.day);
      _eventFilterDate = _selectedTrainingDay;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });
    _rebuildOpenSectionSheet();

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: rows.length > 1 ? 0.78 : 0.62,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _AppColors.cmrBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.fitness_center_rounded, color: _primary, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows.length == 1
                                  ? 'Тренировка за ${DateFormat('dd.MM.yyyy').format(day)}'
                                  : 'Тренировки за ${DateFormat('dd.MM.yyyy').format(day)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cmrTitleText(context, mobile: 18, wide: 19.2, color: const Color(0xFF101828)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rows.length == 1
                                  ? 'Подробности, посещаемость, оценки и комментарии'
                                  : 'На эту дату найдено записей: ${rows.length}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(size: 12, color: const Color(0xFF667085), weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF667085),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...rows.map((e) => _buildTrainingDetailsSheetCard(e, sheetContext)).toList(),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadPlayerTrainingHistory(force: true);
      await _loadAttendanceLog(force: true);
    }
    _rebuildOpenSectionSheet();
  }

  Widget _buildTrainingDetailsSheetCard(Map<String, dynamic> raw, BuildContext sheetContext) {
    final e = _enrichTrainingRecord(raw);
    final id = _asInt(e["event_id"] ?? e["id"]);
    final title = _firstNotEmpty([e["title"], e["event_title"], e["name"]]).trim();
    final date = _anyDateStr(e);
    final type = _firstNotEmpty([e["type"], e["training_type"], e["category"]]).trim();
    final typeLabel = _ruTrainingType(type);
    final description = _firstNotEmpty([e["description"], e["body"], e["details"]]).trim();
    final status = _attendanceStatusOf(e);
    final lateMin = _asInt(e["late_minutes"] ?? e["late"]);
    final meta = _statusMeta(status, lateMin);

    final playerRating = _firstRatingValue(e, _playerRatingKeys);
    final coachRating = _firstRatingValue(e, _coachRatingKeys);
    final coachComment = _firstNotEmpty([
      e["coach_comment"],
      e["trainer_comment"],
      e["comment"],
    ]).trim();
    final note = _firstNotEmpty([
      e["coach_note"],
      e["trainer_note"],
      e["note_coach"],
      e["note"],
      e["attendance_note"],
    ]).trim();
    final playerNote = _firstNotEmpty([
      e["player_note"],
      e["self_note"],
      e["diary_note"],
      e["player_comment"],
      e["self_comment"],
    ]).trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(meta.icon, color: meta.color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Тренировка' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(size: 15, color: const Color(0xFF101828)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (typeLabel.isNotEmpty) typeLabel,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _matchDetailPill(meta.icon, 'Статус', meta.text, color: meta.color),
              _matchDetailPill(Icons.star_rounded, 'Оценка игрока', playerRating == null ? '—' : '★ ${_asInt(playerRating)}/5', color: Colors.amber.shade700),
              _matchDetailPill(Icons.workspace_premium_rounded, 'Оценка тренера', coachRating == null ? '—' : '★ ${_asInt(coachRating)}/5', color: Colors.blue.shade700),
              if (typeLabel.isNotEmpty) _matchDetailPill(Icons.category_rounded, 'Тип', typeLabel),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _matchDetailTextBlock(Icons.description_outlined, 'Описание тренировки', description),
          ],
          if (coachComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _matchDetailTextBlock(Icons.chat_bubble_outline_rounded, 'Комментарий тренера', coachComment),
          ],
          if (playerNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            _matchDetailTextBlock(Icons.menu_book_rounded, 'Заметка игрока', playerNote),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _matchDetailTextBlock(Icons.sticky_note_2_outlined, 'Заметка', note),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactActionButton(
                icon: Icons.visibility_rounded,
                label: 'Показать в списке',
                onTap: () async {
                  setState(() {
                    selectedEvent = e;
                    selectedEventPlayerInfo = null;
                    final d = _parseEventDate(e);
                    if (d != null) {
                      _selectedTrainingDay = DateTime(d.year, d.month, d.day);
                      _eventFilterDate = _selectedTrainingDay;
                    }
                  });
                  _rebuildOpenSectionSheet();
                  Navigator.of(sheetContext).pop(false);
                  if (id > 0) await _loadPlayerInfoForEvent(id);
                  _rebuildOpenSectionSheet();
                },
                compact: false,
              ),
              _compactActionButton(
                icon: Icons.star_rounded,
                label: 'Оценка',
                onTap: id <= 0
                    ? null
                    : () async {
                        setState(() {
                          selectedEvent = e;
                          selectedEventPlayerInfo = null;
                        });
                        _rebuildOpenSectionSheet();
                        Navigator.of(sheetContext).pop(false);
                        await _loadPlayerInfoForEvent(id);
                        if (mounted) await _openCoachRatingSheet();
                        _rebuildOpenSectionSheet();
                      },
                compact: false,
              ),
              _compactActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Заметка',
                onTap: id <= 0
                    ? null
                    : () async {
                        setState(() {
                          selectedEvent = e;
                          selectedEventPlayerInfo = null;
                        });
                        _rebuildOpenSectionSheet();
                        Navigator.of(sheetContext).pop(false);
                        await _loadPlayerInfoForEvent(id);
                        if (mounted) await _openCoachNoteSheet();
                        _rebuildOpenSectionSheet();
                      },
                compact: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingSplitSelector() {
    if (eventsLoading) {
      return _buildCmrCard(
        child: Center(child: Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(color: _primary))),
      );
    }
    if (eventsError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: eventsError!,
        action: TextButton(
          onPressed: () => _loadPlayerTrainingHistory(force: true),
          style: TextButton.styleFrom(foregroundColor: _primary),
          child: const Text('Повторить'),
        ),
      );
    }

    final list = _filteredEvents();
    final selectedDate = _selectedTrainingDay ?? _eventFilterDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: _eventSearchC,
                  onChanged: (_) {
                    setState(() {});
                    _rebuildOpenSectionSheet();
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    hintText: 'Поиск тренировки...',
                    prefixIcon: Icon(Icons.search_rounded, size: 17),
                    hintStyle: TextStyle(fontSize: 11.2),
                  ),
                  style: TextStyle(fontFamily: _fontFamily, fontSize: 11.2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildCmrActionChip(
              icon: Icons.refresh_rounded,
              label: 'Обновить',
              onTap: () async {
                await _loadPlayerTrainingHistory(force: true);
                _rebuildOpenSectionSheet();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.touch_app_rounded, color: _AppColors.cmrGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Выбор тренировки', style: _titleStyle(size: 15, color: const Color(0xFF101828))),
                        const SizedBox(height: 2),
                        Text(
                          selectedDate == null
                              ? 'Выберите дату или карточку — подробности откроются справа.'
                              : 'Дата ${DateFormat('dd.MM.yyyy').format(selectedDate)}. Подробная карточка открывается справа.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(size: 11.8, color: const Color(0xFF667085), weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (teamEvents.isEmpty)
                _buildEmptyState(icon: Icons.event_busy_rounded, message: 'Тренировок за период нет.')
              else if (list.isEmpty)
                _buildEmptyState(
                  icon: Icons.search_off_rounded,
                  message: 'Ничего не найдено по фильтрам.',
                  action: TextButton(
                    onPressed: () {
                      setState(() {
                        _eventSearchC.clear();
                        _eventFilterDate = null;
                        _selectedTrainingDay = null;
                        selectedEvent = null;
                        selectedEventPlayerInfo = null;
                      });
                      _rebuildOpenSectionSheet();
                    },
                    child: const Text('Сбросить'),
                  ),
                )
              else
                Column(
                  children: list.map(_buildTrainingSplitSelectorTile).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingSplitSelectorTile(Map<String, dynamic> raw) {
    final e = _enrichTrainingRecord(raw);
    final id = _trainingRowEventId(e);
    final selectedId = _trainingRowEventId(selectedEvent ?? const <String, dynamic>{});
    final selected = id > 0 && id == selectedId;
    final title = _firstNotEmpty([e['title'], e['event_title'], e['name']]).trim();
    final date = _anyDateStr(e);
    final type = _firstNotEmpty([e['type'], e['training_type'], e['category']]).trim();
    final typeLabel = _ruTrainingType(type);
    final status = _attendanceStatusOf(e);
    final lateMin = _asInt(e['late_minutes'] ?? e['late']);
    final meta = _statusMeta(status, lateMin);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _AppColors.cmrSoft : _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _selectTrainingForDetails(e, loadInfo: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: selected ? Colors.white : _AppColors.softFor(meta.color), borderRadius: BorderRadius.circular(13)),
                  child: Icon(meta.icon, color: meta.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.isEmpty ? 'Тренировка' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 13.2, color: const Color(0xFF101828), weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text([if (date.isNotEmpty) date, if (typeLabel.isNotEmpty) typeLabel].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(meta.icon, size: 13, color: meta.color),
                      const SizedBox(width: 5),
                      Text(meta.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11, color: meta.color, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsSubTab() {
    if (eventsLoading) {
      return Center(child: CircularProgressIndicator(color: _primary));
    }
    if (eventsError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: eventsError!,
        action: TextButton(
          onPressed: () => _loadPlayerTrainingHistory(force: true),
          style: TextButton.styleFrom(foregroundColor: _primary),
          child: const Text("Повторить"),
        ),
      );
    }

    final list = _filteredEvents();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _eventSearchC,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    hintText: "Поиск тренировки...",
                    prefixIcon: Icon(Icons.search_rounded, size: 17),
                    hintStyle: TextStyle(fontSize: 11.2),
                  ),
                  style: TextStyle(fontFamily: _fontFamily, fontSize: 11.2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildCmrActionChip(
              icon: Icons.refresh_rounded,
              label: 'Обновить',
              onTap: () => _loadPlayerTrainingHistory(force: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (teamEvents.isEmpty)
          _buildEmptyState(
            icon: Icons.event_busy_rounded,
            message: "Тренировок за период нет.",
            action: TextButton(
              onPressed: () => _loadPlayerTrainingHistory(force: true),
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text("Обновить"),
            ),
          )
        else if (list.isEmpty)
          _buildEmptyState(
            icon: Icons.search_off_rounded,
            message: "Ничего не найдено по фильтрам.",
            action: TextButton(
              onPressed: () {
                setState(() {
                  _eventSearchC.clear();
                  _eventFilterDate = null;
                  _selectedTrainingDay = null;
                  selectedEvent = null;
                  selectedEventPlayerInfo = null;
                });
                _rebuildOpenSectionSheet();
                _loadPlayerTrainingHistory(force: true).then((_) => _rebuildOpenSectionSheet());
              },
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text("Сбросить фильтры"),
            ),
          )
        else
          ..._buildEventsGroupedByDate(list),
        const SizedBox(height: 12),
        if (selectedEvent != null && !_usesCmrRightDetailsPane(context)) _buildSelectedEventPlayerInfoCard(),
      ],
    );
  }

  Widget _buildSelectedEventPlayerInfoCard() {
    if (selectedEventPlayerInfo == null) {
      return _buildCmrCard(
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (selectedEventPlayerInfo?['error'] != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: _asStr(selectedEventPlayerInfo?['error']),
      );
    }

    final info = _enrichTrainingRecord(selectedEventPlayerInfo!);
    final title = _firstNotEmpty([info['title'], info['event_title'], info['name']]).trim();
    final date = _anyDateStr(info);
    final type = _firstNotEmpty([info['type'], info['training_type'], info['category']]).trim();
    final typeLabel = _ruTrainingType(type);
    final status = _firstNotEmpty([info['status'], info['attendance_status'], info['presence_status']]);
    final late = _asInt(info['late_minutes'] ?? info['late']);
    final reason = _firstNotEmpty([info['reason'], info['absence_reason']]).trim();
    final playerRating = _firstRatingValue(info, _playerRatingKeys);
    final coachRating = _firstRatingValue(info, _coachRatingKeys);
    final coachComment = _firstNotEmpty([info['coach_comment'], info['trainer_comment'], info['comment']]).trim();
    final coachNote = _firstNotEmpty([info['coach_note'], info['trainer_note'], info['note_coach']]).trim();
    final playerNote = _firstNotEmpty([info['player_note'], info['self_note'], info['diary_note'], info['player_comment'], info['self_comment']]).trim();
    final meta = _statusMeta(status, late);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrainingTopReportCard(
          title: title,
          date: date,
          typeLabel: typeLabel,
          meta: meta,
          reason: reason,
        ),
        _buildTrainingScoreGrid(playerRating: playerRating, coachRating: coachRating),
        const SizedBox(height: 10),
        _buildTrainingProfessionalNote(
          icon: Icons.menu_book_rounded,
          title: 'Заметка игрока',
          text: playerNote,
          accent: _AppColors.cmrGreen,
          subtleWhenEmpty: playerNote.isEmpty,
        ),
        if (coachComment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildTrainingProfessionalNote(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Комментарий тренера',
            text: coachComment,
            accent: _AppColors.blue,
          ),
        ],
        const SizedBox(height: 10),
        _buildTrainingProfessionalNote(
          icon: Icons.sticky_note_2_outlined,
          title: 'Заметка тренера',
          text: coachNote,
          accent: _AppColors.orange,
          subtleWhenEmpty: coachNote.isEmpty,
        ),
        const SizedBox(height: 12),
        _buildCmrActionChip(
          icon: Icons.edit_note_rounded,
          label: 'Добавить заметку тренера',
          compact: true,
          onTap: _openCoachNoteSheet,
        ),
      ],
    );
  }

  ({String text, Color color, IconData icon}) _statusMeta(
      String st, int lateMinutes) {
    final s = st.trim().toLowerCase();

    switch (s) {
      case "present":
      case "присутствует":
      case "был":
      case "на тренировке":
        return (
          text: "Присутствует",
          color: const Color(0xFF178A45),
          icon: Icons.check_circle_rounded,
        );
      case "absent":
      case "отсутствует":
      case "не был":
      case "пропуск":
        return (
          text: "Отсутствует",
          color: const Color(0xFFEF4444),
          icon: Icons.cancel_rounded,
        );
      case "late":
      case "опоздал":
      case "опоздание":
        return (
          text: lateMinutes > 0 ? "Опоздал на ${lateMinutes} мин" : "Опоздал",
          color: const Color(0xFFF59E0B),
          icon: Icons.schedule_rounded,
        );
      case "sick":
      case "болен":
      case "болезнь":
        return (
          text: "Болен",
          color: const Color(0xFFF59E0B),
          icon: Icons.sick_rounded,
        );
      case "injured":
      case "травма":
      case "травмирован":
        return (
          text: "Травма",
          color: const Color(0xFFDC2626),
          icon: Icons.healing_rounded,
        );
      case "individual":
      case "индивидуально":
      case "индивид.":
        return (
          text: "Индивид.",
          color: const Color(0xFF0EA5E9),
          icon: Icons.person_rounded,
        );
      case "dayoff":
      case "выходной":
      case "отдых":
        return (
          text: "Выходной",
          color: const Color(0xFF9CA3AF),
          icon: Icons.beach_access_rounded,
        );
      case "unset":
      case "":
      case "none":
      case "не отмечено":
        return (
          text: "Не отмечено",
          color: const Color(0xFF667085),
          icon: Icons.help_outline_rounded,
        );
      default:
        return (
          text: s.isNotEmpty ? s : "Не отмечено",
          color: Colors.grey.shade600,
          icon: Icons.help_outline_rounded,
        );
    }
  }


  Widget _buildActivityProRatingsCalendar() {
    final now = DateTime.now();
    final base = _selectedTrainingDay ?? now;
    final month = DateTime(base.year, base.month, 1);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final row in attendanceLog) {
      final d = _parseEventDate(row);
      if (d == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
      byDay.putIfAbsent(key, () => []).add(row);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _calendarArrow(Icons.chevron_left_rounded, () {
                setState(() {
                  _selectedTrainingDay = DateTime(month.year, month.month - 1, 1);
                  _eventFilterDate = _selectedTrainingDay;
                });
                _rebuildOpenSectionSheet();
              }),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('LLLL yyyy', 'ru').format(month),
                    style: _titleStyle(size: 14.5, color: const Color(0xFF101828)),
                  ),
                ),
              ),
              _calendarArrow(Icons.chevron_right_rounded, () {
                setState(() {
                  _selectedTrainingDay = DateTime(month.year, month.month + 1, 1);
                  _eventFilterDate = _selectedTrainingDay;
                });
                _rebuildOpenSectionSheet();
              }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => Expanded(child: Center(child: Text(d, style: _bodyStyle(size: 10.5, color: const Color(0xFF667085), weight: FontWeight.w700)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: total,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, i) {
              final dayNum = i - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

              final day = DateTime(month.year, month.month, dayNum);
              final key = DateFormat('yyyy-MM-dd').format(day);
              final rows = byDay[key] ?? const <Map<String, dynamic>>[];
              final selected = _selectedTrainingDay != null && _sameDateOnly(day, _selectedTrainingDay!);
              final today = _sameDateOnly(day, now);

              int coachSum = 0;
              int coachCnt = 0;
              int playerSum = 0;
              int playerCnt = 0;
              String status = '';

              for (final row in rows) {
                final st = _attendanceStatusOf(row);
                if (status.isEmpty || st == 'absent' || st == 'late' || st == 'injured') status = st;

                final coach = _firstRatingValue(row, _coachRatingKeys);
                if (coach != null) {
                  coachSum += _asInt(coach);
                  coachCnt++;
                }

                final player = _firstRatingValue(row, _playerRatingKeys);
                if (player != null) {
                  playerSum += _asInt(player);
                  playerCnt++;
                }
              }

              final int coachAvg = coachCnt == 0
                  ? 0
                  : ((coachSum / coachCnt).round() < 1
                      ? 1
                      : ((coachSum / coachCnt).round() > 5 ? 5 : (coachSum / coachCnt).round()));
              final int playerAvg = playerCnt == 0
                  ? 0
                  : ((playerSum / playerCnt).round() < 1
                      ? 1
                      : ((playerSum / playerCnt).round() > 5 ? 5 : (playerSum / playerCnt).round()));
              final meta = _statusMeta(status, 0);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedTrainingDay = day;
                    _eventFilterDate = day;
                    selectedEvent = null;
                    selectedEventPlayerInfo = null;
                  });
                  _rebuildOpenSectionSheet();
                  if (rows.isNotEmpty) _showTrainingDayDetailsSheet(day, rows);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected
                        ? _primary.withOpacity(0.12)
                        : rows.isNotEmpty
                            ? Colors.white
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 10.7,
                          fontWeight: FontWeight.w700,
                          color: selected ? _primary : const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (rows.isNotEmpty) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: meta.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (coachAvg > 0) _ratingTinyBadge('Т', coachAvg, Colors.blue.shade700),
                            if (coachAvg > 0 && playerAvg > 0) const SizedBox(width: 2),
                            if (playerAvg > 0) _ratingTinyBadge('И', playerAvg, Colors.amber.shade800),
                          ],
                        ),
                      ] else
                        const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _activityLegendDot(const Color(0xFF178A45), 'Присутствие'),
              _activityLegendDot(const Color(0xFFF59E0B), 'Опоздание/болезнь'),
              _activityLegendDot(const Color(0xFFEF4444), 'Пропуск'),
              _activityLegendBadge('Т', 'оценка тренера'),
              _activityLegendBadge('И', 'оценка игрока'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingTinyBadge(String prefix, int rating, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$prefix$rating',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 7.4,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _activityLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: _bodyStyle(size: 10.5, color: const Color(0xFF667085), weight: FontWeight.w600)),
      ],
    );
  }

  Widget _activityLegendBadge(String prefix, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ratingTinyBadge(prefix, 5, prefix == 'Т' ? Colors.blue.shade700 : Colors.amber.shade800),
        const SizedBox(width: 5),
        Text(label, style: _bodyStyle(size: 10.5, color: const Color(0xFF667085), weight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAttendanceSubTab() {
    if (attendanceLoading && attendanceLog.isEmpty) {
      return _buildCmrCard(
        child: Center(child: Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(color: _primary))),
      );
    }
    if (attendanceError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: attendanceError!,
        action: TextButton(
          onPressed: () => _loadAttendanceLog(force: true),
          style: TextButton.styleFrom(foregroundColor: _primary),
          child: const Text('Повторить'),
        ),
      );
    }

    final rows = _attendanceRowsForMonth().where(_attendanceMatchesFilter).toList();
    final visibleRows = _attendanceShowAll ? rows : rows.take(5).toList();
    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('События за период', style: _cmrTitleText(context, mobile: 15.8, wide: 17, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Нажмите на строку — подробный отчёт откроется справа', style: _cmrSubtitleText(context, mobile: 11.4, wide: 12.2, color: _AppColors.textSecondary, weight: FontWeight.w700)),
                  ],
                ),
              ),
              _buildAttendanceFilterChip(),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _buildEmptyState(
              icon: Icons.event_available_rounded,
              message: 'Нет записей посещаемости за период.',
              action: TextButton(
                onPressed: () => _loadAttendanceLog(force: true),
                style: TextButton.styleFrom(foregroundColor: _primary),
                child: const Text('Обновить'),
              ),
            )
          else
            Column(children: visibleRows.map(_buildAttendanceTimelineRow).toList()),
          if (rows.length > 5) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  _safeSetState(() => _attendanceShowAll = !_attendanceShowAll);
                  _rebuildOpenSectionSheet();
                },
                icon: Icon(_attendanceShowAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                label: Text(_attendanceShowAll ? 'Свернуть' : 'Показать ещё'),
                style: TextButton.styleFrom(foregroundColor: _AppColors.info, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _attendanceFilterLabel(String value) {
    switch (value) {
      case 'training':
        return 'Тренировки';
      case 'match':
        return 'Матчи';
      case 'test':
        return 'Тесты';
      case 'present':
        return 'Присутствовал';
      case 'late':
        return 'Опоздание';
      case 'absent':
        return 'Отсутствовал';
      default:
        return 'Все типы';
    }
  }

  bool _attendanceMatchesFilter(Map<String, dynamic> row) {
    final value = _attendanceTypeFilter;
    if (value == 'all') return true;
    final type = _attendanceEventTypeLabel(row).toLowerCase();
    final status = _attendanceStatusOf(row);
    if (value == 'training') return type.contains('трен');
    if (value == 'match') return type.contains('матч');
    if (value == 'test') return type.contains('тест');
    if (value == 'present') return status == 'present' || status == 'individual';
    if (value == 'late') return status == 'late';
    if (value == 'absent') return status == 'absent';
    return true;
  }

  Widget _buildAttendanceFilterChip() {
    return PopupMenuButton<String>(
      initialValue: _attendanceTypeFilter,
      tooltip: 'Фильтр посещаемости',
      onSelected: (value) {
        _safeSetState(() {
          _attendanceTypeFilter = value;
          _attendanceShowAll = false;
        });
        _rebuildOpenSectionSheet();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'all', child: Text('Все типы')),
        PopupMenuItem(value: 'training', child: Text('Тренировки')),
        PopupMenuItem(value: 'match', child: Text('Матчи')),
        PopupMenuItem(value: 'test', child: Text('Тесты')),
        PopupMenuItem(value: 'present', child: Text('Присутствовал')),
        PopupMenuItem(value: 'late', child: Text('Опоздание')),
        PopupMenuItem(value: 'absent', child: Text('Отсутствовал')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.filter_alt_rounded, color: _AppColors.textSecondary, size: 16),
          const SizedBox(width: 7),
          Text(_attendanceFilterLabel(_attendanceTypeFilter), style: _bodyStyle(size: 11.5, color: _AppColors.textSecondary, weight: FontWeight.w700)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary, size: 16),
        ]),
      ),
    );
  }

  Widget _buildAttendanceTimelineRow(Map<String, dynamic> raw) {
    final row = _enrichTrainingRecord(Map<String, dynamic>.from(raw));
    final d = _parseEventDate(row);
    final title = _firstNotEmpty([row['title'], row['event_title'], row['name']]).trim();
    final stage = _attendanceStageLabel(row);
    final typeLabel = _attendanceEventTypeLabel(row);
    final st = _attendanceStatusOf(row);
    final late = _attendanceLateMinutes(row);
    final meta = _statusMeta(st, late);
    final activeId = _trainingRowEventId(selectedEvent ?? const <String, dynamic>{});
    final rowId = _trainingRowEventId(row);
    final active = rowId > 0 && activeId == rowId;
    final accent = typeLabel == 'Матч'
        ? _AppColors.blue
        : typeLabel == 'Тестирование'
            ? _AppColors.info
            : _AppColors.cmrGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectTrainingForDetails(row, loadInfo: true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(d == null ? '—' : DateFormat('d', 'ru').format(d), style: _bodyStyle(size: 17, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                    Text(d == null ? '' : DateFormat('MMM', 'ru').format(d).replaceAll('.', '').toUpperCase(), style: _bodyStyle(size: 10.2, color: _AppColors.textSecondary, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(14)),
                child: Icon(_trainingTypeIcon(typeLabel), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? typeLabel : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 13.4, wide: 14.2, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(stage, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 11, wide: 11.7, color: _AppColors.textSecondary, weight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _attendanceStatusPill(meta.icon, meta.text, meta.color),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: _AppColors.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceStatusPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.3, color: color, weight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildAttendanceMobileReportCard() {
    return _buildAttendanceReportContent(_trainingDetailsSelection(), wrapInCard: true);
  }

  Widget _buildAttendanceReportContent(Map<String, dynamic>? source, {bool wrapInCard = false}) {
    final item = source == null ? null : _enrichTrainingRecord(Map<String, dynamic>.from(source));
    if (item == null) {
      final empty = _buildEmptyState(icon: Icons.event_busy_rounded, message: 'Выберите дату или событие для отчёта посещаемости.');
      return wrapInCard ? _buildCmrCard(child: empty) : empty;
    }

    final status = _attendanceStatusOf(item);
    final late = _attendanceLateMinutes(item);
    final meta = _statusMeta(status, late);
    final trainer = _attendanceTrainerName(item);
    final reason = _firstNotEmpty([item['reason'], item['absence_reason'], item['status_reason']]).trim();
    final coachComment = _firstNotEmpty([item['coach_comment'], item['trainer_comment'], item['comment'], item['coach_note'], item['trainer_note']]).trim();
    final role = _firstNotEmpty([item['role'], item['lesson_role'], item['training_role'], item['squad_role']]).trim();
    final intensity = _firstNotEmpty([item['intensity'], item['training_intensity'], item['load_intensity']]).trim();
    final arrival = _attendanceTimeText(item, const ['arrival_time', 'arrived_at', 'check_in', 'time_in', 'start_at']);
    final departure = _attendanceTimeText(item, const ['leave_time', 'departure_time', 'left_at', 'check_out', 'time_out', 'end_at']);
    final duration = _attendanceDurationText(item);
    final punctuality = status == 'late'
        ? (late > 0 ? 'Опоздание ($late мин)' : 'Опоздание')
        : (status == 'absent' ? 'Не был' : 'Вовремя');
    final negative = _isNegativeAttendance(item);
    final titleStyleColor = negative ? _AppColors.error : _AppColors.textPrimary;
    final recommendation = negative
        ? 'Проверить причину пропуска или опоздания и согласовать восстановительный план.'
        : 'Продолжать поддерживать высокий уровень посещаемости и пунктуальности.';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _attendanceStatusPill(meta.icon, meta.text, meta.color),
            const Spacer(),
            if (trainer.isNotEmpty) ...[
              const Icon(Icons.people_alt_rounded, color: _AppColors.textSecondary, size: 17),
              const SizedBox(width: 6),
              Flexible(child: Text('Тренер: $trainer', maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12, color: _AppColors.textSecondary, weight: FontWeight.w700))),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text('Статус посещения', style: _cmrTitleText(context, mobile: 14.8, wide: 15.8, color: titleStyleColor, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final twoCols = c.maxWidth >= 360;
          final gap = 10.0;
          final w = twoCols ? (c.maxWidth - gap) / 2 : c.maxWidth;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            SizedBox(width: w, child: _attendanceReportMetric(Icons.login_rounded, 'Время прибытия', arrival, _AppColors.cmrGreen)),
            SizedBox(width: w, child: _attendanceReportMetric(Icons.logout_rounded, 'Время ухода', departure, _AppColors.cmrGreen)),
            SizedBox(width: w, child: _attendanceReportMetric(Icons.timer_outlined, 'Длительность', duration, _AppColors.cmrGreen)),
            SizedBox(width: w, child: _attendanceReportMetric(Icons.schedule_rounded, 'Пунктуальность', punctuality, status == 'late' ? _AppColors.orange : (status == 'absent' ? _AppColors.error : _AppColors.cmrGreen))),
            SizedBox(width: w, child: _attendanceReportMetric(Icons.groups_2_rounded, 'Роль на занятии', role.isEmpty ? 'Основной состав' : role, _AppColors.cmrGreen)),
            SizedBox(width: w, child: _attendanceReportMetric(Icons.trending_up_rounded, 'Интенсивность', intensity.isEmpty ? 'Высокая' : intensity, _AppColors.cmrGreen)),
          ]);
        }),
        const SizedBox(height: 14),
        _matchDetailTextBlock(Icons.help_outline_rounded, 'Причина', reason.isEmpty ? '—' : reason),
        if (coachComment.isNotEmpty) ...[
          const SizedBox(height: 12),
          _matchDetailTextBlock(Icons.chat_bubble_outline_rounded, 'Комментарий тренера', coachComment),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(20)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.flag_rounded, color: _AppColors.cmrGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Рекомендация', style: _cmrTitleText(context, mobile: 14.2, wide: 15.2, color: _AppColors.textPrimary, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(recommendation, style: _cmrSubtitleText(context, mobile: 12, wide: 12.4, color: _AppColors.textSecondary, weight: FontWeight.w700)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Динамика посещаемости', style: _cmrTitleText(context, mobile: 14.8, wide: 15.8, color: _AppColors.textPrimary, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _attendanceDynamicsTile('${_attendancePresentStreak()}', 'посещений подряд', 'Лучшая серия', Icons.trending_up_rounded, _AppColors.cmrGreen)),
          const SizedBox(width: 10),
          Expanded(child: _attendanceDynamicsTile('${_attendanceRowsForMonth().where((x) => _attendanceStatusOf(x) == 'absent').length}', 'пропуска за месяц', 'Улучшение', Icons.trending_down_rounded, _AppColors.cmrGreen)),
        ]),
      ],
    );

    return wrapInCard ? _buildCmrCard(child: content) : content;
  }

  Widget _attendanceReportMetric(IconData icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), ),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent, size: 16)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.7, color: _AppColors.textSecondary, weight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.3, color: accent == _AppColors.error ? _AppColors.error : _AppColors.textPrimary, weight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _attendanceDynamicsTile(String value, String title, String subtitle, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: _cmrTitleText(context, mobile: 22, wide: 24, color: _AppColors.textPrimary, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.2, color: _AppColors.textSecondary, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.8, color: _AppColors.textSecondary, weight: FontWeight.w700))),
          Icon(icon, color: accent, size: 15),
        ]),
      ]),
    );
  }

  Widget _buildTrainingAttendanceCardsList(List<Map<String, dynamic>> rows) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 820;
        final columns = c.maxWidth >= 1160 ? 3 : (wide ? 2 : 1);
        final gap = wide ? 12.0 : 10.0;
        final itemWidth = columns == 1 ? c.maxWidth : (c.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: rows
              .map(
                (x) => SizedBox(
                  width: itemWidth,
                  child: _buildTrainingAttendanceCard(x, compact: !wide),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTrainingAttendanceCard(Map<String, dynamic> raw, {required bool compact}) {
    final x = _enrichTrainingRecord(raw);
    final eventTitle = _asStr(x['title'] ?? x['event_title'] ?? x['name']).trim();
    final date = _anyDateStr(x);
    final st = _attendanceStatusOf(x);
    final lateMin = _asInt(x['late_minutes'] ?? x['late']);
    final reason = _firstNotEmpty([x['reason'], x['absence_reason']]).trim();
    final coachComment = _firstNotEmpty([x['coach_comment'], x['trainer_comment'], x['comment']]).trim();
    final attendanceNote = _firstNotEmpty([x['note'], x['attendance_note']]).trim();
    final coachNote = _firstNotEmpty([x['coach_note'], x['trainer_note'], x['note_coach']]).trim();
    final meta = _statusMeta(st, lateMin);
    final playerRating = _firstRatingValue(x, _playerRatingKeys);
    final coachRating = _firstRatingValue(x, _coachRatingKeys);

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: _AppColors.softFor(meta.color),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(meta.icon, color: meta.color, size: compact ? 20 : 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isEmpty ? 'Дата не указана' : date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 14.4, wide: 15.4, color: const Color(0xFF101828), weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eventTitle.isEmpty ? meta.text : eventTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrSubtitleText(context, mobile: 11.4, wide: 12.2, color: const Color(0xFF667085), weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildTrainingMetaPill(meta.icon, meta.text, meta.color),
              _buildTrainingMetaPill(Icons.star_rounded, playerRating == null ? 'Игрок: —' : 'Игрок: ${_asInt(playerRating)}/5', _AppColors.cmrGreen),
              _buildTrainingMetaPill(Icons.workspace_premium_rounded, coachRating == null ? 'Тренер: —' : 'Тренер: ${_asInt(coachRating)}/5', _AppColors.cmrGreen),
              if (reason.isNotEmpty) _buildTrainingMetaPill(Icons.info_outline_rounded, reason, _AppColors.orange),
            ],
          ),
          if (coachComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _noteBox(icon: Icons.chat_bubble_outline_rounded, title: 'Комментарий тренера', text: coachComment),
          ],
          if (attendanceNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _noteBox(icon: Icons.fact_check_outlined, title: 'Заметка посещения', text: attendanceNote),
          ],
          if (coachNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _noteBox(icon: Icons.sticky_note_2_outlined, title: 'Заметка тренера', text: coachNote),
          ],
        ],
      ),
    );
  }

  Widget _buildIndividualSubTab() {
    final playerId = _asInt(widget.player['user_id']);
    final filtered = _filteredCalendarEvents();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _AppColors.cmrSoftPanel,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _AppColors.softFor(_AppColors.cmrGreen),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: _AppColors.cmrGreen, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Личные задания',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 15.4, wide: 16.4, color: const Color(0xFF101828), weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Индивидуальная нагрузка и события календаря игрока в едином компактном виде.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrSubtitleText(context, mobile: 12.2, wide: 12.8, color: const Color(0xFF667085), weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTrainingMetaPill(Icons.event_note_outlined, 'Событий: ${calendarEvents.length}', _AppColors.cmrGreen),
                        _buildTrainingMetaPill(Icons.person_pin_circle_outlined, 'Формат: личные', _AppColors.cmrGreen),
                        _buildTrainingMetaPill(Icons.verified_user_outlined, 'Контроль: тренер', _AppColors.cmrGreen),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCmrActionChip(icon: Icons.add_task_rounded, label: 'Назначить', compact: true, onTap: _assignTraining),
            ],
          ),
        ),
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _calendarSearchC,
                onChanged: (_) {
                  setState(() {});
                  _rebuildOpenSectionSheet();
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _AppColors.cmrSoftPanel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  hintText: 'Поиск по личным заданиям…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  hintStyle: _bodyStyle(size: 12, color: const Color(0xFF94A3B8), weight: FontWeight.w700),
                ),
                style: _bodyStyle(size: 12.4, color: const Color(0xFF101828), weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (calendarLoading)
          _buildCmrCard(child: Center(child: CircularProgressIndicator(color: _primary)))
        else if (calendarError != null)
          _buildEmptyState(
            icon: Icons.error_outline_rounded,
            message: calendarError!,
            action: TextButton(
              onPressed: () => _loadTeamCalendar(force: true),
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text('Повторить'),
            ),
          )
        else if (filtered.isEmpty)
          _buildEmptyState(
            icon: Icons.event_busy_rounded,
            message: 'Индивидуальных заданий пока нет.',
            action: TextButton(
              onPressed: _assignTraining,
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text('Назначить'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 820;
              final columns = c.maxWidth >= 1160 ? 3 : (wide ? 2 : 1);
              final gap = wide ? 12.0 : 10.0;
              final itemWidth = columns == 1 ? c.maxWidth : (c.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: filtered
                    .map((e) => SizedBox(width: itemWidth, child: _buildCalendarEventCard(e)))
                    .toList(),
              );
            },
          ),
        const SizedBox(height: 12),
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _AppColors.softFor(_AppColors.cmrGreen),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.history_rounded, color: _AppColors.cmrGreen, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'История личных тренировок',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 14.2, wide: 15.2, color: const Color(0xFF101828), weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TrainingHistoryWidget(playerId: playerId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCalendarBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_month_rounded, color: _primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Календарь команды",
                  style: _titleStyle(size: 14, color: _textPrimary),
                ),
              ),
              IconButton(
                tooltip: "Обновить",
                onPressed: () => _loadTeamCalendar(force: true),
                icon: Icon(Icons.refresh_rounded, color: _primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickCalendarRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, color: _primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _calendarRangeText(),
                            style: TextStyle(
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                                fontSize: 11.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_calendarFrom != null || _calendarTo != null)
                          IconButton(
                            onPressed: _clearCalendarRange,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: _textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: _textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _calendarSearchC,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: "Поиск по календарю (тип, название, место)…",
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (calendarLoading)
            Center(child: CircularProgressIndicator(color: _primary))
          else if (calendarError != null)
            _buildEmptyState(
              icon: Icons.error_outline_rounded,
              message: calendarError!,
              action: TextButton(
                onPressed: () => _loadTeamCalendar(force: true),
                style: TextButton.styleFrom(foregroundColor: _primary),
                child: const Text("Повторить"),
              ),
            )
          else if (_filteredCalendarEvents().isEmpty)
            _buildEmptyState(
              icon: Icons.event_busy_rounded,
              message: "Событий команды за период нет.",
              action: TextButton(
                onPressed: () => _loadTeamCalendar(force: true),
                style: TextButton.styleFrom(foregroundColor: _primary),
                child: const Text("Обновить"),
              ),
            )
          else
            ..._filteredCalendarEvents()
                .map((e) => _buildCalendarEventCard(e))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildCalendarEventCard(Map<String, dynamic> e) {
    final type = _asStr(e['type']).trim();
    final typeLabel = _ruTrainingType(type);
    final title = _asStr(e['title']).trim().isEmpty ? 'Событие' : _asStr(e['title']).trim();
    final startAt = _fmtTime(_asStr(e['start_at']));
    final endAt = _fmtTime(_asStr(e['end_at']));
    final location = _asStr(e['location']).trim();
    final notes = _asStr(e['notes']).trim();
    final accent = _trainingTypeAccent(typeLabel.isEmpty ? type : typeLabel);
    final icon = _trainingTypeIcon(typeLabel.isEmpty ? type : typeLabel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _AppColors.softFor(accent),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 14.2, wide: 15.2, color: const Color(0xFF101828), weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endAt.isEmpty ? (startAt.isEmpty ? 'Время не указано' : startAt) : '$startAt — $endAt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrSubtitleText(context, mobile: 11.4, wide: 12.2, color: const Color(0xFF667085), weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (typeLabel.isNotEmpty) _buildTrainingMetaPill(Icons.category_rounded, typeLabel, accent),
              if (location.isNotEmpty) _buildTrainingMetaPill(Icons.location_on_outlined, location, _AppColors.cmrGreen),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _noteBox(icon: Icons.info_outline_rounded, title: 'Заметки', text: notes),
          ],
        ],
      ),
    );
  }

  // =============================
  // МАТЧИ
  // =============================
  Widget _buildMatchesTab() {
    final selectedMatches = _selectedMatchDay == null
        ? matches
        : matches.where((m) {
            final d = _matchDateOf(m);
            return d != null && _sameDateOnly(d, _selectedMatchDay!);
          }).toList();

    final withVideo = matches.where((x) => _asStr(x["video_url"]).trim().isNotEmpty).length;
    final withTtd = matches.where((x) => _asStr(x["ttd_text"]).trim().isNotEmpty).length;
    final withNotes = matches.where((x) => _asStr(x["notes"] ?? x["coach_comment"] ?? x["comment"]).trim().isNotEmpty).length;
    final withScore = matches.where((x) => _matchScore(x).trim().isNotEmpty).length;
    final splitMode = _isWideSplitDetailsMode();

    return _buildCmrSectionShell(
      title: 'Матчи',
      subtitle: 'Игровая история игрока: даты, соперники, счёт, видео и ТТД',
      icon: Icons.sports_score_rounded,
      stats: [
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_score_outlined),
        _buildCmrMiniStat('Со счётом', '$withScore', Icons.scoreboard_outlined),
        _buildCmrMiniStat('Видео', '$withVideo', Icons.play_circle_outline_rounded),
        _buildCmrMiniStat('ТТД', '$withTtd', Icons.analytics_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_rounded, label: 'Матч', onTap: () => _showEditMatchDialog()),
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => _loadMatches(force: true), compact: true),
      ],
      children: [
        if (!splitMode)
          _buildInlineCalendarHeader(
            title: 'Календарь матчей',
            subtitle: 'Даты с играми отмечены. Выбор даты фильтрует карточки ниже.',
            expanded: _matchesCalendarExpanded,
            onToggle: () => _safeSetState(() => _matchesCalendarExpanded = !_matchesCalendarExpanded),
          ),
        if (splitMode || _matchesCalendarExpanded) ...[
          if (!splitMode) const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: matches,
            dateOf: _matchDateOf,
            selectedDay: _selectedMatchDay,
            displayMonth: _matchesCalendarMonth ?? _selectedMatchDay ?? DateTime.now(),
            onMonthChanged: (month) => _safeSetState(() => _matchesCalendarMonth = month),
            onSelect: (d) {
              _safeSetState(() {
                _selectedMatchDay = d;
                _matchesCalendarMonth = DateTime(d.year, d.month, 1);
              });
              _rebuildOpenSectionSheet();
            },
            loading: matchesLoading,
            onDayWithItemsTap: (day, dayMatches) {
              if (_usesCmrRightDetailsPane(context)) {
                if (dayMatches.isNotEmpty) {
                  _selectMatchForDetails(Map<String, dynamic>.from(dayMatches.first));
                }
                return;
              }
              _showMatchDayDetailsSheet(day, dayMatches);
            },
          ),
        ],
        if (_selectedMatchDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(
            date: _selectedMatchDay!,
            label: 'Показаны матчи за дату',
            onClear: () {
              setState(() => _selectedMatchDay = null);
              _rebuildOpenSectionSheet();
            },
          ),
        ],
        const SizedBox(height: 12),
        if (matchesLoading)
          _buildCmrCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (matchesError != null)
          _buildEmptyState(icon: Icons.error_outline_rounded, message: matchesError!)
        else if (matches.isEmpty)
          _buildEmptyState(
            icon: Icons.sports_soccer_rounded,
            message: 'Матчей пока нет. Когда тренер добавит игры команды, здесь появится история игрока.',
            action: TextButton(onPressed: () => _loadMatches(force: true), child: const Text('Обновить')),
          )
        else if (selectedMatches.isEmpty)
          _buildEmptyState(icon: Icons.event_busy_rounded, message: 'На выбранную дату матчей нет.')
        else
          _buildMatchesCardsList(selectedMatches),
        if (matches.isNotEmpty &&
            !_usesCmrRightDetailsPane(context) &&
            (selectedTtdMatch != null ||
                playerTtdLoading ||
                playerTtdError != null ||
                playerTtdSummary.isNotEmpty ||
                playerTtdMainRows.isNotEmpty ||
                playerTtdPassRows.isNotEmpty ||
                playerTtdGoalkeeperRows.isNotEmpty)) ...[
          const SizedBox(height: 12),
          _buildPlayerTtdMatchSelector(),
        ],
      ],
    );
  }

  Widget _buildMatchesCardsList(List<Map<String, dynamic>> rows) {
    return LayoutBuilder(
      builder: (context, c) {
        // Карточки матчей оставляем ниже календаря, но делаем их как «матч-центр»:
        // одна аккуратная лента на обычной ширине и две колонки только на очень широком экране.
        final twoColumns = c.maxWidth >= 1040;
        final gap = twoColumns ? 12.0 : 10.0;
        final itemWidth = twoColumns ? (c.maxWidth - gap) / 2 : c.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: rows
              .map(
                (m) => SizedBox(
                  width: itemWidth,
                  child: _buildMatchActivityCard(m, compact: c.maxWidth < 720),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMatchActivityCard(Map<String, dynamic> m, {required bool compact}) {
    final matchId = _asInt(m["match_id"] ?? m["id"]);
    final opponent = _asStr(m["opponent"]).trim().isEmpty ? "Соперник не указан" : _asStr(m["opponent"]).trim();
    final tournament = _asStr(m["competition_name"] ?? m["tournament"] ?? m["type"]).trim();
    final date = _formatMatchDate(_asStr(m["match_date"] ?? m["date"] ?? m["start_at"]));
    final score = _matchScore(m).trim().isEmpty ? '—' : _matchScore(m).trim();
    final video = _matchVideoUrl(m);
    final hasVideo = video.isNotEmpty;
    final hasTtd = _hasMatchTtd(m);
    final notes = _matchCoachComment(m);
    final resultColor = _matchResultColor(m);
    final resultLabel = _matchResultLabel(m);
    final selectedId = _asInt(selectedTtdMatch?['match_id'] ?? selectedTtdMatch?['id']);
    final active = matchId > 0 && selectedId == matchId;
    final isOpening = _openingPlayerMatchId == matchId && matchId > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          final day = _matchDateOf(m);
          if (_usesCmrRightDetailsPane(context)) {
            _selectMatchForDetails(m);
            return;
          }
          if (day != null) {
            setState(() {
              _selectedMatchDay = day;
              _matchesCalendarMonth = DateTime(day.year, day.month, 1);
            });
            _rebuildOpenSectionSheet();
          }
          _showMatchDayDetailsSheet(day ?? DateTime.now(), [m]);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: active ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: BoxDecoration(
                      color: _AppColors.softFor(_AppColors.cmrGreen),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.sports_soccer_rounded, color: _AppColors.cmrGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                opponent,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _cmrTitleText(
                                  context,
                                  mobile: compact ? 15.0 : 15.8,
                                  wide: 16.6,
                                  color: const Color(0xFF101828),
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildMatchScoreBadge(score: score, color: resultColor, compact: compact),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [
                            if (date.isNotEmpty) date,
                            if (tournament.isNotEmpty) tournament,
                          ].join(' • ').trim().isEmpty
                              ? 'Дата и турнир не указаны'
                              : [
                                  if (date.isNotEmpty) date,
                                  if (tournament.isNotEmpty) tournament,
                                ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _cmrSubtitleText(
                            context,
                            mobile: 11.4,
                            wide: 12.0,
                            color: const Color(0xFF667085),
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _buildMatchMetaPill(Icons.event_rounded, date.isEmpty ? 'Дата не указана' : date, _AppColors.cmrGreen),
                  if (tournament.isNotEmpty) _buildMatchMetaPill(Icons.emoji_events_outlined, tournament, _AppColors.cmrGreen),
                  _buildMatchMetaPill(Icons.analytics_outlined, hasTtd ? 'ТТД есть' : 'ТТД нет', hasTtd ? _AppColors.cmrGreen : _AppColors.textTertiary),
                  _buildMatchMetaPill(Icons.play_circle_outline_rounded, hasVideo ? 'Видео есть' : 'Видео нет', hasVideo ? _AppColors.cmrGreen : _AppColors.textTertiary),
                  _buildMatchMetaPill(Icons.flag_rounded, resultLabel, resultColor),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMatchActivityNote(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Комментарий тренера',
                  text: notes,
                ),
              ],
              if (hasTtd && _asStr(m["ttd_text"]).trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildMatchActivityNote(
                  icon: Icons.analytics_outlined,
                  title: 'ТТД игрока',
                  text: _asStr(m["ttd_text"]).trim(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _compactActionButton(
                          icon: isOpening ? Icons.hourglass_top_rounded : Icons.analytics_outlined,
                          label: isOpening ? 'Открываю...' : 'Показать ТТД',
                          onTap: matchId <= 0 || isOpening ? null : () => _selectMatchForDetails(m, loadTtd: true),
                          compact: compact,
                        ),
                        if (hasVideo)
                          _compactActionButton(
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Видео',
                            onTap: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
                            compact: compact,
                          ),
                        _compactActionButton(
                          icon: Icons.edit_outlined,
                          label: compact ? 'Изм.' : 'Редактировать',
                          onTap: () async => _showEditMatchDialog(m),
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                  if (_usesCmrRightDetailsPane(context)) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 22, color: active ? _AppColors.cmrGreen : const Color(0xFF94A3B8)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchActivityNote({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _AppColors.cmrGreen),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: _bodyStyle(size: 11.5, color: const Color(0xFF475467), weight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: _bodyStyle(size: 11.5, color: const Color(0xFF101828), weight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchMetaPill(IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(size: 11.2, color: accent, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMatchScoreBadge({required String score, required Color color, bool compact = false}) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 48 : 54),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: _AppColors.softFor(color),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        score,
        textAlign: TextAlign.center,
        style: _bodyStyle(size: compact ? 12.4 : 13.2, color: color, weight: FontWeight.w700),
      ),
    );
  }

  String _matchResultLabel(Map<String, dynamic> match) {
    final rawOur = _asStr(match['our_score']).trim();
    final rawOpp = _asStr(match['opponent_score']).trim();
    if (rawOur.isEmpty && rawOpp.isEmpty && _matchScore(match).trim().isEmpty) return 'Без счёта';
    final our = _asInt(match['our_score']);
    final opp = _asInt(match['opponent_score']);
    if (our > opp) return 'Победа';
    if (our == opp) return 'Ничья';
    return 'Поражение';
  }

  Widget _buildMatchPassportHeader({
    required String opponent,
    required String score,
    required String date,
    required String tournament,
    required Color resultColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoft,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.sports_soccer_rounded, color: _AppColors.cmrGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opponent, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 18.0, wide: 19.6, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (date.isNotEmpty) 'Матч за $date',
                        if (tournament.isNotEmpty) tournament,
                      ].join(' • ').trim().isEmpty
                          ? 'Карточка выбранного матча'
                          : [
                              if (date.isNotEmpty) 'Матч за $date',
                              if (tournament.isNotEmpty) tournament,
                            ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrSubtitleText(context, mobile: 12.0, wide: 12.7, color: _AppColors.textSecondary, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildMatchScoreBadge(score: score, color: resultColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchInfoGrid({
    required String date,
    required String tournament,
    required bool hasTtd,
    required bool hasVideo,
    required String resultLabel,
    required Color resultColor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _matchDetailPill(Icons.event_rounded, 'Дата', date.isEmpty ? '—' : date, color: _AppColors.cmrGreen),
        _matchDetailPill(Icons.emoji_events_outlined, 'Турнир', tournament.isEmpty ? '—' : tournament, color: _AppColors.cmrGreen),
        _matchDetailPill(Icons.analytics_outlined, 'ТТД', hasTtd ? 'есть' : 'нет', color: hasTtd ? _AppColors.cmrGreen : _AppColors.textTertiary),
        _matchDetailPill(Icons.play_circle_outline_rounded, 'Видео', hasVideo ? 'есть' : 'нет', color: hasVideo ? _AppColors.cmrGreen : _AppColors.textTertiary),
        _matchDetailPill(Icons.flag_rounded, 'Итог', resultLabel, color: resultColor),
      ],
    );
  }

  Widget _buildMatchMaterialsPanel({required bool hasTtd, required bool hasVideo, required bool hasComment}) {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.analytics_outlined, 'title': 'ТТД игрока', 'value': hasTtd ? 'доступно' : 'нет данных', 'active': hasTtd},
      {'icon': Icons.play_circle_outline_rounded, 'title': 'Видео матча', 'value': hasVideo ? 'доступно' : 'нет видео', 'active': hasVideo},
      {'icon': Icons.chat_bubble_outline_rounded, 'title': 'Комментарий', 'value': hasComment ? 'есть' : 'не заполнен', 'active': hasComment},
      {'icon': Icons.description_outlined, 'title': 'Протокол', 'value': 'матч-центр', 'active': true},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Материалы матча', style: _titleStyle(size: 14.2, color: _AppColors.textPrimary)),
          const SizedBox(height: 10),
          ...items.map((item) {
            final active = item['active'] == true;
            final color = active ? _AppColors.cmrGreen : _AppColors.textTertiary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(13)),
                    child: Icon(item['icon'] as IconData, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 12.2, color: _AppColors.textPrimary, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item['value'] as String, style: _bodyStyle(size: 11.2, color: color, weight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMatchQuickActions({
    required int matchId,
    required Map<String, dynamic> match,
    required String video,
    required bool isOpening,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _compactActionButton(
          icon: isOpening ? Icons.hourglass_top_rounded : Icons.fact_check_outlined,
          label: isOpening ? 'Открываю...' : 'Показать ТТД',
          onTap: matchId <= 0 || isOpening ? null : () => _selectMatchForDetails(match, loadTtd: true),
          compact: false,
        ),
        if (video.isNotEmpty)
          _compactActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Видео',
            onTap: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
            compact: false,
          ),
        _compactActionButton(
          icon: Icons.edit_outlined,
          label: 'Редактировать',
          onTap: () async => _showEditMatchDialog(match),
          compact: false,
        ),
      ],
    );
  }
  Future<void> _showMatchDayDetailsSheet(DateTime day, List<Map<String, dynamic>> dayMatches) async {
    final rows = dayMatches
        .map((x) => Map<String, dynamic>.from(x))
        .toList();

    if (!mounted || rows.isEmpty) return;

    if (_usesCmrRightDetailsPane(context)) {
      await _selectMatchForDetails(rows.first);
      return;
    }

    setState(() {
      _selectedMatchDay = day;
      selectedTtdMatch = rows.first;
    });
    _rebuildOpenSectionSheet();

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: rows.length > 1 ? 0.78 : 0.64,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _AppColors.cmrBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.sports_score_rounded, color: _primary, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows.length == 1 ? 'Матч за ${DateFormat('dd.MM.yyyy').format(day)}' : 'Матчи за ${DateFormat('dd.MM.yyyy').format(day)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cmrTitleText(context, mobile: 18, wide: 19.2, color: const Color(0xFF101828)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rows.length == 1 ? 'Подробная информация по выбранной игре' : 'На эту дату найдено матчей: ${rows.length}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(size: 12, color: const Color(0xFF667085), weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF667085),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...rows.map((m) => _buildMatchDetailsSheetCard(m, sheetContext)).toList(),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadMatches(force: true);
      _rebuildOpenSectionSheet();
    } else {
      setState(() {});
      _rebuildOpenSectionSheet();
    }
  }

  Widget _buildMatchDetailsSheetCard(Map<String, dynamic> m, BuildContext sheetContext) {
    final matchId = _asInt(m['match_id'] ?? m['id']);
    final opponent = _asStr(m['opponent']).trim().isEmpty ? 'Соперник не указан' : _asStr(m['opponent']).trim();
    final tournament = _asStr(m['competition_name'] ?? m['tournament']).trim();
    final date = _formatMatchDate(_asStr(m['match_date'] ?? m['date'] ?? m['start_at']));
    final score = _matchScore(m).isEmpty ? '—' : _matchScore(m);
    final video = _asStr(m['video_url']).trim();
    final ttdText = _asStr(m['ttd_text']).trim();
    final notes = _asStr(m['notes'] ?? m['coach_comment'] ?? m['comment']).trim();
    final isOpening = _openingPlayerMatchId == matchId && matchId > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sports_soccer_rounded, color: _primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(size: 15, color: const Color(0xFF101828)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (tournament.isNotEmpty) tournament,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 54),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  score,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _matchDetailPill(Icons.event_rounded, 'Дата', date.isEmpty ? '—' : date),
              _matchDetailPill(Icons.emoji_events_outlined, 'Турнир', tournament.isEmpty ? '—' : tournament),
              _matchDetailPill(Icons.analytics_outlined, 'ТТД', ttdText.isEmpty ? 'нет' : 'есть'),
              _matchDetailPill(Icons.play_circle_outline_rounded, 'Видео', video.isEmpty ? 'нет' : 'есть'),
            ],
          ),
          if (ttdText.isNotEmpty) ...[
            const SizedBox(height: 12),
            _matchDetailTextBlock(Icons.analytics_outlined, 'ТТД игрока', ttdText),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _matchDetailTextBlock(Icons.chat_bubble_outline_rounded, 'Комментарий тренера', notes),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _compactActionButton(
                icon: isOpening ? Icons.hourglass_top_rounded : Icons.fact_check_outlined,
                label: isOpening ? 'Открываю...' : 'Показать ТТД',
                onTap: matchId <= 0 || isOpening
                    ? null
                    : () async {
                        setState(() {
                          _openingPlayerMatchId = matchId;
                          selectedTtdMatch = m;
                        });
                        _rebuildOpenSectionSheet();
                        Navigator.of(sheetContext).pop(false);
                        await _loadPlayerTtdForMatch(m);
                        if (mounted) {
                          setState(() => _openingPlayerMatchId = 0);
                          _rebuildOpenSectionSheet();
                        }
                      },
                compact: false,
              ),
              if (video.isNotEmpty)
                _compactActionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Видео',
                  onTap: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
                  compact: false,
                ),
              _compactActionButton(
                icon: Icons.edit_outlined,
                label: 'Редактировать',
                onTap: () async {
                  Navigator.of(sheetContext).pop(false);
                  await _showEditMatchDialog(m);
                },
                compact: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchDetailPill(IconData icon, String title, String value, {Color? color}) {
    final c = color ?? _primary;
    final wide = MediaQuery.of(context).size.width >= 720;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 13 : 9, vertical: wide ? 10 : 7),
      decoration: BoxDecoration(
        color: c.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: wide ? 17 : 14, color: c),
          SizedBox(width: wide ? 7 : 5),
          Text(
            '$title: ',
            style: _bodyStyle(size: wide ? 12.2 : 10.8, color: const Color(0xFF475569), weight: FontWeight.w700),
          ),
          Text(
            value,
            style: _bodyStyle(size: wide ? 12.2 : 10.8, color: c, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _matchDetailTextBlock(IconData icon, String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: _bodyStyle(size: 11.5, color: const Color(0xFF334155), weight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: _bodyStyle(size: 11.5, color: const Color(0xFF101828), weight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTable(List<Map<String, dynamic>> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Дата', style: TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: Color(0xFF667085)))),
                Expanded(flex: 3, child: Text('Соперник', style: TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: Color(0xFF667085)))),
                Expanded(flex: 2, child: Text('Счёт', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: Color(0xFF667085)))),
                Expanded(flex: 3, child: Text('Турнир', style: TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: Color(0xFF667085)))),
                Expanded(flex: 2, child: Text('Видео/ТТД', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.6, fontWeight: FontWeight.w700, color: Color(0xFF667085)))),
              ],
            ),
          ),
          ...rows.map(_buildMatchTableRow),
        ],
      ),
    );
  }

  Widget _buildMatchTableRow(Map<String, dynamic> m) {
    final opponent = _asStr(m["opponent"]).isEmpty ? "Соперник" : _asStr(m["opponent"]);
    final tournament = _asStr(m["competition_name"]).isEmpty ? '—' : _asStr(m["competition_name"]);
    final date = _formatMatchDate(_asStr(m["match_date"] ?? m["date"]));
    final score = _matchScore(m).isEmpty ? '—' : _matchScore(m);
    final hasVideo = _asStr(m["video_url"]).trim().isNotEmpty;
    final hasTtd = _asStr(m["ttd_text"]).trim().isNotEmpty;

    return InkWell(
      onTap: () {
        final day = _matchDateOf(m);
        if (_usesCmrRightDetailsPane(context)) {
          _selectMatchForDetails(m);
          return;
        }
        if (day != null) {
          setState(() => _selectedMatchDay = day);
          _rebuildOpenSectionSheet();
        }
        _showMatchDayDetailsSheet(day ?? DateTime.now(), [m]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(date.isEmpty ? '—' : date, style: _bodyStyle(size: 12.5, color: const Color(0xFF101828), weight: FontWeight.w600))),
            Expanded(flex: 3, child: Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.8, color: const Color(0xFF101828), weight: FontWeight.w700))),
            Expanded(flex: 2, child: Text(score, textAlign: TextAlign.center, style: _bodyStyle(size: 12.8, color: const Color(0xFF101828), weight: FontWeight.w700))),
            Expanded(flex: 3, child: Text(tournament, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.2, color: const Color(0xFF667085), weight: FontWeight.w700))),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tableMiniIcon(Icons.play_circle_outline_rounded, hasVideo),
                  const SizedBox(width: 6),
                  _tableMiniIcon(Icons.analytics_outlined, hasTtd),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableMiniIcon(IconData icon, bool active) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 15, color: active ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
    );
  }

  

 Widget _buildMatchCard(Map<String, dynamic> m, {bool compact = false, bool tablet = false}) {
  final matchId = _asInt(m["match_id"] ?? m["id"]);
  final opponent = _asStr(m["opponent"]).isEmpty ? "Соперник не указан" : _asStr(m["opponent"]);
  final tournament = _asStr(m["competition_name"]).isEmpty
      ? ""
      : _asStr(m["competition_name"]);
  final matchDate = _asStr(m["match_date"]).trim();

  final ourScore = _asStr(m["our_score"]).trim();
  final opponentScore = _asStr(m["opponent_score"]).trim();
  final score = (ourScore.isNotEmpty || opponentScore.isNotEmpty)
      ? "$ourScore:$opponentScore"
      : "—";

  final video = _asStr(m["video_url"]).trim();
  final coachComment = _asStr(m["notes"]).trim();
  final ttdText = _asStr(m["ttd_text"]).trim();

  final prettyDate = () {
    if (matchDate.isEmpty) return "Дата не указана";
    final d = DateTime.tryParse(matchDate.replaceAll(' ', 'T'));
    if (d == null) return matchDate;
    return DateFormat('dd.MM.yyyy').format(d);
  }();

  final pad = compact ? 10.0 : 12.0;
  final iconSize = compact ? 34.0 : 38.0;
  final titleSize = compact ? 13.0 : 13.5;
  final metaSize = compact ? 10.5 : 11.0;

  return Container(
    margin: EdgeInsets.only(bottom: tablet ? 0 : 10),
    padding: EdgeInsets.all(pad),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.sports_soccer_rounded, color: _primary, size: compact ? 17 : 19),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opponent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(size: titleSize, color: _textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tournament.isEmpty ? prettyDate : "$prettyDate • $tournament",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(size: metaSize, color: _textSecondary, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 7),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                score,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  fontSize: compact ? 11.5 : 12,
                ),
              ),
            ),
          ],
        ),
        if (ttdText.isNotEmpty || coachComment.isNotEmpty) ...[
          SizedBox(height: compact ? 8 : 10),
          _buildMatchInfoStrip(
            ttdText: ttdText,
            coachComment: coachComment,
            compact: compact,
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        _buildMatchCardActions(m, matchId: matchId, opponent: opponent, tournament: tournament, score: score, matchDate: matchDate, video: video, compact: compact),
      ],
    ),
  );
}

  Widget _buildMatchInfoStrip({required String ttdText, required String coachComment, required bool compact}) {
    final items = <Widget>[];
    if (ttdText.isNotEmpty) {
      items.add(_buildCompactInfoPill(Icons.analytics_outlined, 'ТТД', ttdText, compact: compact));
    }
    if (coachComment.isNotEmpty) {
      items.add(_buildCompactInfoPill(Icons.chat_bubble_outline_rounded, 'Комментарий', coachComment, compact: compact));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 520 && items.length > 1) {
          return Row(
            children: items
                .map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: w)))
                .toList(),
          );
        }
        return Column(
          children: items
              .map((w) => Padding(padding: EdgeInsets.only(bottom: compact ? 6 : 8), child: w))
              .toList(),
        );
      },
    );
  }

  Widget _buildCompactInfoPill(IconData icon, String title, String text, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: _primary),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: _bodyStyle(size: compact ? 10.8 : 11.2, color: _textSecondary, weight: FontWeight.w700),
                children: [
                  TextSpan(text: '$title: ', style: _bodyStyle(size: compact ? 10.8 : 11.2, color: _textPrimary, weight: FontWeight.w700)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCardActions(
    Map<String, dynamic> m, {
    required int matchId,
    required String opponent,
    required String tournament,
    required String score,
    required String matchDate,
    required String video,
    required bool compact,
  }) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _compactActionButton(
          icon: Icons.analytics_outlined,
          label: 'ТТД',
          onTap: matchId <= 0 ? null : () => _loadPlayerTtdForMatch(m),
          compact: compact,
        ),
        if (video.isNotEmpty)
          _compactActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Видео',
            onTap: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
            compact: compact,
          ),
      ],
    );
  }

  Widget _compactActionButton({required IconData icon, required String label, required VoidCallback? onTap, required bool compact}) {
    final wide = MediaQuery.of(context).size.width >= 720;
    final horizontal = compact ? 9.0 : (wide ? 14.0 : 11.0);
    final vertical = compact ? 7.0 : (wide ? 10.0 : 8.0);
    final fg = onTap == null ? _textTertiary : _primary;
    return Material(
      color: onTap == null ? const Color(0xFFF1F5F9) : _primary.withOpacity(wide ? 0.10 : 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 14 : (wide ? 18 : 15), color: fg),
              SizedBox(width: wide && !compact ? 7 : 5),
              Text(label, style: _bodyStyle(size: compact ? 10.8 : (wide ? 12.6 : 11.2), color: fg, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerTtdMatchSelector() {
    final selected = selectedTtdMatch;
    final title = selected == null ? 'Выберите матч для просмотра ТТД' : _matchTitle(selected);

    return _buildCmrCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final tablet = c.maxWidth >= 760;
          final compact = c.maxWidth < 560;

          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.fact_check_outlined, color: _primary, size: compact ? 18 : 20),
              ),
              SizedBox(width: compact ? 9 : 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ТТД по матчу', style: _titleStyle(size: compact ? 13.5 : 14.5, color: _textPrimary)),
                    const SizedBox(height: 3),
                    Text(title, maxLines: tablet ? 1 : 2, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 11 : 11.5, color: _textSecondary, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          );

          final selector = _buildCompactMatchSelectorChips(compact: compact, tablet: tablet);
          final body = _buildSelectedPlayerTtdBody(tablet: tablet, compact: compact);

          if (tablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: header),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: selector),
                  ],
                ),
                const SizedBox(height: 12),
                body,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 10),
              selector,
              const SizedBox(height: 10),
              body,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactMatchSelectorChips({required bool compact, required bool tablet}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: matches.map((m) {
          final id = _asInt(m['match_id'] ?? m['id']);
          final active = selectedTtdMatch != null && id == _asInt(selectedTtdMatch!['match_id'] ?? selectedTtdMatch!['id']);
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              selected: active,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) => _loadPlayerTtdForMatch(m),
              label: Text(_shortMatchTitle(m), overflow: TextOverflow.ellipsis),
              labelStyle: TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10.5 : 11,
                color: active ? Colors.white : _textPrimary,
              ),
              selectedColor: _primary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortMatchTitle(Map<String, dynamic> m) {
    final opponent = _asStr(m['opponent']).trim().isEmpty ? 'Матч' : _asStr(m['opponent']).trim();
    final date = _formatMatchDate(_asStr(m['match_date'] ?? m['date']));
    return date.isEmpty ? opponent : '$opponent • $date';
  }

  String _matchTitle(Map<String, dynamic> m) {
    final opponent = _asStr(m['opponent']).trim().isEmpty ? 'Матч' : _asStr(m['opponent']).trim();
    final tournament = _asStr(m['competition_name'] ?? m['tournament']).trim();
    final date = _formatMatchDate(_asStr(m['match_date'] ?? m['date']));
    final score = _matchScore(m);
    final parts = [opponent, if (score.isNotEmpty) score, if (date.isNotEmpty) date, if (tournament.isNotEmpty) tournament];
    return parts.join(' • ');
  }

  String _matchScore(Map<String, dynamic> m) {
    final our = _asStr(m['our_score']).trim();
    final opp = _asStr(m['opponent_score']).trim();
    if (our.isEmpty && opp.isEmpty) return '';
    return '$our:$opp';
  }

  String _formatMatchDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final d = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (d == null) return s;
    return DateFormat('dd.MM.yyyy').format(d);
  }

  Widget _buildSelectedPlayerTtdBody({bool tablet = false, bool compact = false}) {
    if (selectedTtdMatch == null) {
      return _buildEmptyState(
        icon: Icons.touch_app_outlined,
        message: 'Выберите матч выше или нажмите «ТТД» в карточке матча.',
      );
    }

    if (playerTtdLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: _primary, minHeight: 4, borderRadius: BorderRadius.circular(99)),
      );
    }

    if (playerTtdError != null) {
      return _buildEmptyState(
        icon: Icons.info_outline_rounded,
        message: playerTtdError!,
        action: TextButton(
          onPressed: selectedTtdMatch == null ? null : () => _loadPlayerTtdForMatch(selectedTtdMatch!),
          style: TextButton.styleFrom(foregroundColor: _primary),
          child: const Text('Повторить'),
        ),
      );
    }

    final all = [...playerTtdMainRows, ...playerTtdPassRows, ...playerTtdGoalkeeperRows];
    if (all.isEmpty && playerTtdSummary.isEmpty) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        message: 'По выбранному матчу пока нет сохранённых ТТД для этого игрока.',
      );
    }

    final groups = <Widget>[
      if (playerTtdMainRows.isNotEmpty) _buildTtdRowsGroup('Основные действия', playerTtdMainRows, Icons.sports_soccer_outlined, tablet: tablet, compact: compact),
      if (playerTtdPassRows.isNotEmpty) _buildTtdRowsGroup('Передачи', playerTtdPassRows, Icons.compare_arrows_rounded, tablet: tablet, compact: compact),
      if (playerTtdGoalkeeperRows.isNotEmpty) _buildTtdRowsGroup('Вратарские действия', playerTtdGoalkeeperRows, Icons.sports_handball_outlined, tablet: tablet, compact: compact),
    ];

    if (tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (playerTtdSummary.isNotEmpty) ...[
            _buildTtdSummaryGrid(playerTtdSummary, tablet: true, compact: compact),
            const SizedBox(height: 10),
          ],
          if (groups.length == 1)
            groups.first
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1040 ? 3 : 2;
                final gap = 10.0;
                final itemWidth = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: groups.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
                );
              },
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (playerTtdSummary.isNotEmpty) ...[
          _buildTtdSummaryGrid(playerTtdSummary, tablet: false, compact: compact),
          const SizedBox(height: 10),
        ],
        ...groups,
      ],
    );
  }

  Widget _buildTtdSummaryGrid(Map<String, dynamic> summary, {bool tablet = false, bool compact = false}) {
    final entries = summary.entries
        .where((e) => _asStr(e.value).trim().isNotEmpty)
        .take(tablet ? 8 : 6)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final cols = tablet ? (c.maxWidth >= 980 ? 4 : 3) : (c.maxWidth >= 440 ? 3 : 2);
        final gap = compact ? 7.0 : 8.0;
        final itemWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: entries.map((e) {
            return SizedBox(
              width: itemWidth,
              child: _buildCompactTtdSummaryTile(_ttdLabel(e.key), _ruTtdValue(_asStr(e.value)), compact: compact),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCompactTtdSummaryTile(String title, String value, {required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.query_stats_rounded, size: compact ? 15 : 16, color: _primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: compact ? 14 : 15, color: _textPrimary)),
                const SizedBox(height: 1),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 9.8 : 10.5, color: _textSecondary, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtdRowsGroup(String title, List<Map<String, dynamic>> rows, IconData icon, {bool tablet = false, bool compact = false}) {
    final metricCards = <Widget>[];
    for (final row in rows) {
      metricCards.addAll(_rowToTtdMetricCards(row, compact: compact, tablet: tablet));
    }

    if (metricCards.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: tablet ? 0 : 10),
      padding: EdgeInsets.all(compact ? 10 : 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 28 : 30,
                height: compact ? 28 : 30,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: compact ? 15 : 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: _titleStyle(size: compact ? 12.5 : 13.2, color: _textPrimary))),
              Text('${metricCards.length}', style: _bodyStyle(size: compact ? 10.5 : 11, color: _textSecondary, weight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: compact ? 8 : 9),
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              final cols = tablet
                  ? (width >= 620 ? 3 : 2)
                  : (width >= 460 ? 2 : 1);
              final gap = compact ? 7.0 : 8.0;
              final itemWidth = cols == 1 ? width : (width - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: metricCards.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _rowToTtdMetricCards(Map<String, dynamic> row, {bool compact = false, bool tablet = false}) {
    const skip = {
      'id', 'player_id', 'user_id', 'student_id', 'athlete_id', 'match_id', 'team_id',
      'player_name', 'name', 'full_name', 'avatar', 'photo', 'group_key', 'position',
      'created_at', 'updated_at', 'success', 'status',
    };

    if (row.containsKey('metric') || row.containsKey('title')) {
      final title = _asStr(row['metric'] ?? row['title'] ?? row['name']).trim();
      final value = _asStr(row['value'] ?? row['count'] ?? row['result']).trim();
      if (title.isNotEmpty || value.isNotEmpty) {
        return [
          _buildTtdMetricCard(
            title.isEmpty ? 'Показатель' : _ttdLabel(title),
            value.isEmpty ? '—' : _ruTtdValue(value),
            compact: compact,
            tablet: tablet,
          ),
        ];
      }
    }

    final cards = <Widget>[];
    for (final e in row.entries) {
      if (skip.contains(e.key)) continue;
      final value = _asStr(e.value).trim();
      if (value.isEmpty || value == '0' || value == '0/0') continue;
      cards.add(_buildTtdMetricCard(_ttdLabel(e.key), _ruTtdValue(value), compact: compact, tablet: tablet));
    }
    return cards;
  }

  Widget _buildTtdMetricCard(String title, String value, {bool compact = false, bool tablet = false}) {
    final parsed = _parseSuccessFail(value);
    final percent = parsed == null ? null : (parsed[2] == 0 ? 0 : (parsed[0] / parsed[2] * 100));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 10.2 : 10.8, color: _textSecondary, weight: FontWeight.w600)),
          SizedBox(height: compact ? 5 : 6),
          Row(
            children: [
              Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: compact ? 14 : 15.5, color: _textPrimary))),
              if (percent != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7, vertical: 3),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.09), borderRadius: BorderRadius.circular(999)),
                  child: Text('${percent.toStringAsFixed(0)}%', style: _bodyStyle(size: compact ? 9.5 : 10, color: _primary, weight: FontWeight.w700)),
                ),
            ],
          ),
          if (parsed != null) ...[
            SizedBox(height: compact ? 6 : 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: parsed[2] == 0 ? 0 : parsed[0] / parsed[2],
                minHeight: tablet ? 4 : 4.5,
                color: _primary,
                backgroundColor: _AppColors.cmrBorder,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<int>? _parseSuccessFail(String value) {
    final parts = value.split('/');
    if (parts.length != 2) return null;
    final success = int.tryParse(parts[0].trim()) ?? 0;
    final fail = int.tryParse(parts[1].trim()) ?? 0;
    return [success, fail, success + fail];
  }

  String _ttdLabel(String key) {
    final original = key.trim();
    if (original.isEmpty) return 'Показатель';

    final normalized = original
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase()
        .trim();

    const labels = <String, String>{
      // Общие итоги
      'total': 'Всего действий',
      'ttd_total': 'Всего ТТД',
      'success_total': 'Успешные действия',
      'successful_total': 'Успешные действия',
      'fail_total': 'Неуспешные действия',
      'failed_total': 'Неуспешные действия',
      'errors_total': 'Ошибки',
      'effect_percent': 'Эффективность',
      'efficiency': 'Эффективность',
      'success_percent': 'Успешность',
      'accuracy': 'Точность',
      'rating': 'Оценка',
      'episodes': 'Эпизоды',
      'count': 'Количество',
      'value': 'Значение',
      'result': 'Результат',
      'minutes': 'Минуты',
      'minute': 'Минута',
      'time': 'Время',
      'period': 'Тайм',
      'half': 'Тайм',

      // Основные ТТД
      'feint_dribble': 'Финты / обводка',
      'dribble': 'Дриблинг',
      'dribbles': 'Дриблинг',
      'feint': 'Финт',
      'shot_on_goal': 'Удары по воротам',
      'shots_on_goal': 'Удары по воротам',
      'shot': 'Удар',
      'shots': 'Удары',
      'goal': 'Гол',
      'goals': 'Голы',
      'assist': 'Голевая передача',
      'assists': 'Голевые передачи',
      'key_pass': 'Ключевая передача',
      'key_passes': 'Ключевые передачи',
      'tackle_duel': 'Отбор / единоборства',
      'tackle': 'Отбор',
      'tackles': 'Отборы',
      'duel': 'Единоборство',
      'duels': 'Единоборства',
      'interception': 'Перехват',
      'interceptions': 'Перехваты',
      'recovery': 'Подбор',
      'recoveries': 'Подборы',
      'loss': 'Потеря',
      'losses': 'Потери',
      'foul': 'Фол',
      'fouls': 'Фолы',
      'fouls_won': 'Заработанные фолы',
      'fouls_committed': 'Совершённые фолы',
      'header_play': 'Игра головой',
      'headers': 'Игра головой',
      'throw_ins': 'Ауты',
      'corner': 'Угловой',
      'corners': 'Угловые',
      'offside': 'Офсайд',
      'offsides': 'Офсайды',
      'yellow_card': 'Жёлтые карточки',
      'red_card': 'Красные карточки',

      // Передачи
      'pass': 'Передача',
      'passes': 'Передачи',
      'pass_total': 'Всего передач',
      'pass_success': 'Успешные передачи',
      'pass_fail': 'Неуспешные передачи',
      'pass_accuracy': 'Точность передач',
      'pass_avp': 'Пасы в АВП',
      'pass_short': 'Короткие передачи',
      'pass_medium': 'Средние передачи',
      'pass_long': 'Длинные передачи',
      'forward_short': 'Вперёд короткие',
      'forward_medium': 'Вперёд средние',
      'forward_long': 'Вперёд длинные',
      'side_short': 'Поперёк короткие',
      'side_medium': 'Поперёк средние',
      'side_long': 'Поперёк длинные',
      'back_short': 'Назад короткие',
      'back_medium': 'Назад средние',
      'back_long': 'Назад длинные',
      'cross': 'Навес',
      'crosses': 'Навесы',
      'through_ball': 'Проникающая передача',
      'long_ball': 'Длинная передача',

      // Вратарь
      'goalkeeper': 'Вратарь',
      'gk': 'Вратарь',
      'save': 'Сейв',
      'saves': 'Сейвы',
      'goals_conceded': 'Пропущенные мячи',
      'clean_sheet': 'Матч без пропущенных',
      'hand_distribution': 'Ввод рукой',
      'foot_distribution': 'Ввод ногой',
      'coming_out': 'Выходы',
      'close_combat': 'Ближний бой',
      'outside_box': 'Игра за штрафной',
      'catch': 'Ловля мяча',
      'punch': 'Вынос кулаком',
    };

    if (labels.containsKey(normalized)) return labels[normalized]!;

    // Если API уже прислал русское название — оставляем его, но чистим разделители.
    final hasCyrillic = RegExp(r'[А-Яа-яЁё]').hasMatch(original);
    if (hasCyrillic) {
      return original.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final words = normalized
        .split('_')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => labels[w] ?? _singleEnglishTtdWordToRu(w))
        .toList();

    final translated = words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return translated.isEmpty ? 'Показатель' : translated;
  }

  String _singleEnglishTtdWordToRu(String word) {
    const words = <String, String>{
      'player': 'игрока',
      'team': 'команды',
      'match': 'матча',
      'video': 'видео',
      'total': 'всего',
      'success': 'успешные',
      'successful': 'успешные',
      'failed': 'неуспешные',
      'fail': 'неуспешные',
      'error': 'ошибка',
      'errors': 'ошибки',
      'percent': 'процент',
      'rate': 'процент',
      'accuracy': 'точность',
      'efficiency': 'эффективность',
      'count': 'количество',
      'value': 'значение',
      'result': 'результат',
      'avg': 'среднее',
      'average': 'среднее',
      'max': 'максимум',
      'min': 'минимум',
      'distance': 'дистанция',
      'speed': 'скорость',
      'sprint': 'спринт',
      'sprints': 'спринты',
      'moment': 'момент',
      'moments': 'моменты',
      'episode': 'эпизод',
      'episodes': 'эпизоды',
      'action': 'действие',
      'actions': 'действия',
      'rating': 'оценка',
      'note': 'заметка',
      'notes': 'заметки',
      'comment': 'комментарий',
      'comments': 'комментарии',
      'main': 'основные',
      'report': 'отчёт',
      'row': 'строка',
      'rows': 'строки',
      'pass': 'передача',
      'passes': 'передачи',
      'shot': 'удар',
      'shots': 'удары',
      'goal': 'гол',
      'goals': 'голы',
      'assist': 'голевая',
      'assists': 'голевые',
      'tackle': 'отбор',
      'tackles': 'отборы',
      'duel': 'единоборство',
      'duels': 'единоборства',
      'interception': 'перехват',
      'interceptions': 'перехваты',
      'recovery': 'подбор',
      'recoveries': 'подборы',
      'header': 'головой',
      'headers': 'головой',
      'dribble': 'дриблинг',
      'dribbles': 'дриблинг',
      'forward': 'вперёд',
      'back': 'назад',
      'side': 'поперёк',
      'short': 'короткие',
      'medium': 'средние',
      'long': 'длинные',
      'goalkeeper': 'вратаря',
      'gk': 'вратаря',
      'save': 'сейв',
      'saves': 'сейвы',
    };
    return words[word] ?? word;
  }

  String _ruTtdValue(String value) {
    var v = value.trim();
    if (v.isEmpty) return v;

    const replacements = <String, String>{
      'success': 'успешно',
      'successful': 'успешно',
      'failed': 'неуспешно',
      'fail': 'неуспешно',
      'error': 'ошибка',
      'errors': 'ошибки',
      'yes': 'да',
      'no': 'нет',
      'true': 'да',
      'false': 'нет',
      'good': 'хорошо',
      'bad': 'плохо',
      'excellent': 'отлично',
      'normal': 'нормально',
      'high': 'высокий',
      'medium': 'средний',
      'low': 'низкий',
      'left': 'левая',
      'right': 'правая',
      'both': 'обе',
    };

    replacements.forEach((from, to) {
      v = v.replaceAll(RegExp('\\b$from\\b', caseSensitive: false), to);
    });

    return v;
  }

  // =============================
  // ДНЕВНИК
  // =============================
  Widget _buildDiaryTab() {
    final selectedItems = _selectedDiaryDay == null
        ? diaryItems
        : diaryItems.where((x) {
            final d = _diaryDateOf(x);
            return d != null && _sameDateOnly(d, _selectedDiaryDay!);
          }).toList();

    final rated = diaryItems.where((x) => _asInt(x["rating"]) > 0).length;
    final avg = rated == 0 ? 0.0 : diaryItems.fold<int>(0, (sum, x) => sum + _asInt(x["rating"]).clamp(0, 5)) / rated;
    final notes = diaryItems.where((x) => _asStr(x["note"]).trim().isNotEmpty).length;
    final splitMode = _isWideSplitDetailsMode();

    return _buildCmrSectionShell(
      title: 'Дневник игрока',
      subtitle: 'Оценки, самочувствие и заметки игрока собраны в одном разделе',
      icon: Icons.menu_book_rounded,
      stats: [
        _buildCmrMiniStat('Записи', '${diaryItems.length}', Icons.article_outlined),
        _buildCmrMiniStat('Средняя', rated == 0 ? '—' : avg.toStringAsFixed(1), Icons.star_outline_rounded),
        _buildCmrMiniStat('С заметками', '$notes', Icons.sticky_note_2_outlined),
        _buildCmrMiniStat('Даты', '${_markedDays(diaryItems, _diaryDateOf).length}', Icons.calendar_month_outlined),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: _loadDiary),
      ],
      children: [
        if (!splitMode)
          _buildInlineCalendarHeader(
            title: 'Календарь дневника',
            subtitle: 'Даты с записями подсвечены. Выберите день, чтобы отфильтровать историю.',
            expanded: _diaryCalendarExpanded,
            onToggle: () => _safeSetState(() => _diaryCalendarExpanded = !_diaryCalendarExpanded),
          ),
        if (splitMode || _diaryCalendarExpanded) ...[
          if (!splitMode) const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: diaryItems,
            dateOf: _diaryDateOf,
            selectedDay: _selectedDiaryDay,
            displayMonth: _diaryCalendarMonth ?? _selectedDiaryDay ?? DateTime.now(),
            onMonthChanged: (month) => _safeSetState(() => _diaryCalendarMonth = month),
            onSelect: (d) => _safeSetState(() {
              _selectedDiaryDay = d;
              _diaryCalendarMonth = DateTime(d.year, d.month, 1);
            }),
            loading: diaryLoading,
          ),
        ],
        if (_selectedDiaryDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(
            date: _selectedDiaryDay!,
            label: 'Показаны записи за дату',
            onClear: () => _safeSetState(() => _selectedDiaryDay = null),
          ),
        ],
        const SizedBox(height: 12),
        if (diaryLoading)
          _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())))
        else if (diaryError != null)
          _buildEmptyState(icon: Icons.error_outline_rounded, message: diaryError!, action: TextButton(onPressed: _loadDiary, child: const Text('Повторить')))
        else if (diaryItems.isEmpty)
          _buildEmptyState(icon: Icons.menu_book_rounded, message: 'Самооценок пока нет. После тренировок игрок будет оставлять оценки — здесь появится история.', action: TextButton(onPressed: _loadDiary, child: const Text('Обновить')))
        else if (selectedItems.isEmpty)
          _buildEmptyState(icon: Icons.event_busy_rounded, message: 'На выбранную дату записей дневника нет.')
        else
          Column(children: selectedItems.map((x) => _buildDiaryCmrCard(x)).toList()),
      ],
    );
  }

  

  Widget _buildDiaryCmrCard(Map<String, dynamic> x) {
    final rating = _asInt(x["rating"]).clamp(0, 5);
    final note = _asStr(x["note"]).trim();
    final title = _diaryTitle(x);
    final date = _diaryDate(x);
    final selected = identical(_selectedDiaryForDetails, x) ||
        (_selectedDiaryForDetails != null &&
            _asStr(_selectedDiaryForDetails!['id']) == _asStr(x['id']) &&
            _asStr(x['id']).isNotEmpty);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          setState(() => _selectedDiaryForDetails = Map<String, dynamic>.from(x));
          _rebuildOpenSectionSheet();
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _AppColors.cmrSoft : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14, color: const Color(0xFF101828))),
                        const SizedBox(height: 3),
                        Text(date.isEmpty ? 'Дата не указана' : date, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.5, color: const Color(0xFF667085), weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$rating/5', style: _bodyStyle(size: 11.5, color: const Color(0xFF101828), weight: FontWeight.w700)),
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                _noteBox(icon: Icons.sticky_note_2_outlined, title: 'Заметка игрока', text: note),
              ],
              if (selected) ...[
                const SizedBox(height: 10),
                _buildTrainingMetaPill(Icons.check_circle_rounded, 'Открыто справа', _AppColors.blue),
              ],
            ],
          ),
        ),
      ),
    );
  }


  // =============================
  // РЕДАКТИРОВАНИЕ ПРОФИЛЬНЫХ ДАННЫХ И PDF
  // =============================
  Map<String, String> _splitMetricLine(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return {'title': '', 'value': ''};
    final idx = text.indexOf(':');
    if (idx < 0) return {'title': text, 'value': ''};
    return {
      'title': text.substring(0, idx).trim(),
      'value': text.substring(idx + 1).trim(),
    };
  }

  String _joinMetricLine(TextEditingController title, TextEditingController value) {
    final t = title.text.trim();
    final v = value.text.trim();
    if (t.isEmpty && v.isEmpty) return '';
    if (v.isEmpty) return t;
    return '$t: $v';
  }

  Future<void> _showEditMetricsDialog() async {
    if (_usesCmrRightDetailsPane(context)) {
      _openRightEditor(_CmrRightEditorMode.metrics);
      return;
    }

    final initialMetrics = metrics.isNotEmpty
        ? List<String>.from(metrics)
        : _asStr(widget.player['sport_data'])
            .split(RegExp(r'[\n,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final titleControllers = <TextEditingController>[];
    final valueControllers = <TextEditingController>[];

    void addControllerPair([String raw = '']) {
      final parsed = _splitMetricLine(raw);
      titleControllers.add(TextEditingController(text: parsed['title'] ?? ''));
      valueControllers.add(TextEditingController(text: parsed['value'] ?? ''));
    }

    if (initialMetrics.isEmpty) {
      addControllerPair('Рост: ');
      addControllerPair('Вес: ');
      addControllerPair('Голы: ');
    } else {
      for (final item in initialMetrics) {
        addControllerPair(item);
      }
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool saving = false;

        Future<void> saveMetrics(StateSetter setModalState) async {
          if (saving) return;
          final nextMetrics = <String>[];
          for (int i = 0; i < titleControllers.length; i++) {
            final line = _joinMetricLine(titleControllers[i], valueControllers[i]);
            if (line.isNotEmpty) nextMetrics.add(line);
          }

          setModalState(() => saving = true);
          try {
            final value = nextMetrics.join('\n');
            await _savePlayerField({'sport_data': value, 'metrics': value});
            if (Navigator.of(sheetContext).canPop()) {
              Navigator.of(sheetContext).pop(nextMetrics);
            }
          } catch (_) {
            setModalState(() => saving = false);
            if (mounted) _showSnack('Не удалось сохранить метрики');
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

            Widget metricRow(int index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.speed_rounded, color: Color(0xFF178A45), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: isTablet ? 3 : 2,
                      child: TextField(
                        controller: titleControllers[index],
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('Показатель').copyWith(
                          hintText: 'Например: Рост',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        ),
                        style: _bodyStyle(size: isTablet ? 13 : 12.2, color: const Color(0xFF101828), weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: isTablet ? 2 : 2,
                      child: TextField(
                        controller: valueControllers[index],
                        enabled: !saving,
                        textInputAction: TextInputAction.done,
                        decoration: _inputDecoration('Значение').copyWith(
                          hintText: '175 см',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        ),
                        style: _bodyStyle(size: isTablet ? 13 : 12.2, color: const Color(0xFF101828), weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Удалить показатель',
                      onPressed: saving
                          ? null
                          : () {
                              if (titleControllers.length <= 1) {
                                titleControllers[index].clear();
                                valueControllers[index].clear();
                                setModalState(() {});
                                return;
                              }
                              final title = titleControllers.removeAt(index);
                              final value = valueControllers.removeAt(index);
                              title.dispose();
                              value.dispose();
                              setModalState(() {});
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: const Color(0xFFDC2626),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: DraggableScrollableSheet(
                initialChildSize: isTablet ? 0.72 : 0.86,
                minChildSize: 0.48,
                maxChildSize: 0.96,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(isTablet ? 22 : 16, 12, isTablet ? 22 : 16, 20),
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(color: _AppColors.cmrBorder, borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5EE),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: const Icon(Icons.query_stats_rounded, color: Color(0xFF178A45), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Редактор метрик', style: _titleStyle(size: isTablet ? 20 : 18, color: const Color(0xFF101828))),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Добавляйте показатели отдельными строками: рост, вес, голы, передачи, скорость и любые свои метрики.',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: _bodyStyle(size: isTablet ? 12.5 : 11.5, color: const Color(0xFF667085), weight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF178A45), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Название и значение разделены на два поля — так карточки метрик будут выглядеть ровно и на телефоне, и на планшете.',
                                  style: _bodyStyle(size: 11.6, color: const Color(0xFF14532D), weight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(titleControllers.length, metricRow),
                        const SizedBox(height: 2),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () {
                                  addControllerPair();
                                  setModalState(() {});
                                },
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text('Добавить показатель', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF178A45),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving ? null : () => Navigator.of(sheetContext).pop(null),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: saving ? null : () => saveMetrics(setModalState),
                                icon: saving
                                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(saving ? 'Сохраняю...' : 'Сохранить', style: const TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF178A45),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    for (final c in titleControllers) {
      c.dispose();
    }
    for (final c in valueControllers) {
      c.dispose();
    }

    if (result != null && mounted) {
      final value = result.join('\n');
      setState(() {
        metrics = result;
        widget.player['sport_data'] = value;
        widget.player['metrics'] = value;
      });
      _showSnack('Метрики обновлены');
    }
  }

  Future<void> _showEditAchievementsDialog() async {
    final current = _asStr(widget.player['achievements']).trim();
    final titleC = TextEditingController();
    final dateC = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final eventC = TextEditingController();
    final descriptionC = TextEditingController(text: current);
    String selectedType = 'Награда';

    final types = <Map<String, dynamic>>[
      {'title': 'Награда', 'icon': Icons.emoji_events_rounded},
      {'title': 'Турнир', 'icon': Icons.shield_rounded},
      {'title': 'MVP', 'icon': Icons.workspace_premium_rounded},
      {'title': 'Вызов', 'icon': Icons.flag_rounded},
      {'title': 'Рекорд', 'icon': Icons.trending_up_rounded},
      {'title': 'Эпизод', 'icon': Icons.bolt_rounded},
    ];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditSheet(
        title: 'Редактор достижений',
        subtitle: 'Фиксируйте награды, турниры, MVP, вызовы и сильные игровые эпизоды.',
        icon: Icons.workspace_premium_rounded,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            Widget typeChip(Map<String, dynamic> item) {
              final title = item['title'].toString();
              final selected = selectedType == title;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setModalState(() => selectedType = title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF5EE) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'] as IconData, size: 17, color: selected ? const Color(0xFF178A45) : const Color(0xFF667085)),
                      SizedBox(width: _isDesktopOrTablet(context) ? 12 : 7),
                      Text(title, style: _bodyStyle(size: 12, color: selected ? const Color(0xFF101828) : const Color(0xFF667085), weight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EE),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.military_tech_rounded, color: Color(0xFF178A45), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Карточка достижения', style: _titleStyle(size: 15, color: const Color(0xFF101828))),
                            const SizedBox(height: 3),
                            Text('Заполните коротко: тип, дата, турнир и описание. Это будет красиво отображаться в портфолио игрока.', style: _bodyStyle(size: 11.5, color: const Color(0xFF667085), weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Тип достижения', style: _titleStyle(size: 13.5, color: const Color(0xFF101828))),
                const SizedBox(height: 9),
                Wrap(spacing: 8, runSpacing: 8, children: types.map(typeChip).toList()),
                const SizedBox(height: 14),
                TextField(
                  controller: titleC,
                  decoration: _inputDecoration('Название достижения'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: dateC, decoration: _inputDecoration('Дата'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: eventC, decoration: _inputDecoration('Турнир / событие'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionC,
                  minLines: 7,
                  maxLines: 14,
                  decoration: _inputDecoration('Описание и список достижений'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTinyEditorButton(
                      icon: Icons.add_rounded,
                      label: 'Добавить в описание',
                      onTap: () {
                        final title = titleC.text.trim();
                        final date = dateC.text.trim();
                        final event = eventC.text.trim();
                        if (title.isEmpty && event.isEmpty) return;
                        final line = [
                          '• $selectedType${title.isNotEmpty ? ': $title' : ''}',
                          if (date.isNotEmpty) 'Дата: $date',
                          if (event.isNotEmpty) 'Событие: $event',
                        ].join(' · ');
                        final old = descriptionC.text.trim();
                        descriptionC.text = old.isEmpty ? line : '$old\n$line';
                        descriptionC.selection = TextSelection.fromPosition(TextPosition(offset: descriptionC.text.length));
                        setModalState(() {});
                      },
                    ),
                    _buildTinyEditorButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Шаблон MVP',
                      onTap: () {
                        final old = descriptionC.text.trim();
                        const line = '• MVP матча · ключевой вклад в результат команды · стабильная игра и лидерство на поле';
                        descriptionC.text = old.isEmpty ? line : '$old\n$line';
                        descriptionC.selection = TextSelection.fromPosition(TextPosition(offset: descriptionC.text.length));
                        setModalState(() => selectedType = 'MVP');
                      },
                    ),
                    _buildTinyEditorButton(
                      icon: Icons.cleaning_services_outlined,
                      label: 'Очистить',
                      onTap: () {
                        titleC.clear();
                        eventC.clear();
                        descriptionC.clear();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        onSave: () async {
          final title = titleC.text.trim();
          final date = dateC.text.trim();
          final event = eventC.text.trim();
          final text = descriptionC.text.trim();
          final header = [
            if (title.isNotEmpty) '$selectedType: $title',
            if (date.isNotEmpty) 'Дата: $date',
            if (event.isNotEmpty) 'Событие: $event',
          ].join(' · ');
          final value = [
            if (header.isNotEmpty) header,
            if (text.isNotEmpty) text,
          ].join('\n').trim();
          await _savePlayerField({'achievements': value});
          setState(() => widget.player['achievements'] = value);
          if (mounted) Navigator.pop(context, true);
        },
      ),
    );
    titleC.dispose();
    dateC.dispose();
    eventC.dispose();
    descriptionC.dispose();
    if (saved == true && mounted) _showSnack('Достижения обновлены');
  }

  Future<void> _showAddMediaDialog() async {
    if (_usesCmrRightDetailsPane(context)) {
      _openRightEditor(_CmrRightEditorMode.media);
      return;
    }

    final urlController = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditSheet(
        title: 'Добавить медиа',
        subtitle: 'Вставьте ссылку на фото, видео или файл игрока.',
        icon: Icons.add_photo_alternate_outlined,
        child: TextField(
          controller: urlController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration('Ссылка на медиа'),
        ),
        onSave: () async {
          final url = urlController.text.trim();
          if (url.isEmpty) return;
          final next = [...mediaLinks, url];
          final joined = next.join('\n');
          await _savePlayerField({'media': joined, 'media_links': joined});
          setState(() {
            mediaLinks = next;
            widget.player['media'] = joined;
            widget.player['media_links'] = joined;
          });
          if (mounted) Navigator.pop(context, true);
        },
      ),
    );
    urlController.dispose();
    if (saved == true && mounted) _showSnack('Медиа добавлено');
  }

  Future<void> _showEditMatchDialog([Map<String, dynamic>? match]) async {
    final isEdit = match != null;
    final opponentC = TextEditingController(text: isEdit ? _asStr(match['opponent']) : '');
    final dateC = TextEditingController(text: isEdit ? _asStr(match['match_date']) : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final tournamentC = TextEditingController(text: isEdit ? _asStr(match['competition_name']) : '');
    final ourScoreC = TextEditingController(text: isEdit ? _asStr(match['our_score']) : '');
    final opponentScoreC = TextEditingController(text: isEdit ? _asStr(match['opponent_score']) : '');
    final videoC = TextEditingController(text: isEdit ? _asStr(match['video_url']) : '');
    final notesC = TextEditingController(text: isEdit ? _asStr(match['notes']) : '');
    final ttdC = TextEditingController(text: isEdit ? _asStr(match['ttd_text']) : '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditSheet(
        title: isEdit ? 'Редактировать матч' : 'Добавить матч',
        subtitle: 'Игровая история, счёт, видео и ТТД игрока.',
        icon: Icons.sports_score_outlined,
        child: Column(
          children: [
            TextField(controller: opponentC, decoration: _inputDecoration('Соперник')),
            const SizedBox(height: 10),
            TextField(controller: dateC, decoration: _inputDecoration('Дата матча, например 2026-05-05')),
            const SizedBox(height: 10),
            TextField(controller: tournamentC, decoration: _inputDecoration('Турнир / соревнование')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: ourScoreC, keyboardType: TextInputType.number, decoration: _inputDecoration('Голы команды'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: opponentScoreC, keyboardType: TextInputType.number, decoration: _inputDecoration('Голы соперника'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: videoC, decoration: _inputDecoration('Ссылка на видео')),
            const SizedBox(height: 10),
            TextField(controller: ttdC, minLines: 2, maxLines: 4, decoration: _inputDecoration('ТТД')),
            const SizedBox(height: 10),
            TextField(controller: notesC, minLines: 2, maxLines: 4, decoration: _inputDecoration('Комментарий тренера')),
          ],
        ),
        onSave: () async {
          final payload = {
            'id': isEdit ? _asStr(match['id'] ?? match['match_id']) : '',
            'match_id': isEdit ? _asStr(match['match_id'] ?? match['id']) : '',
            'player_id': '${await _resolvePlayerId()}',
            'team_id': '$_teamId',
            'opponent': opponentC.text.trim(),
            'match_date': dateC.text.trim(),
            'competition_name': tournamentC.text.trim(),
            'our_score': ourScoreC.text.trim(),
            'opponent_score': opponentScoreC.text.trim(),
            'video_url': videoC.text.trim(),
            'ttd_text': ttdC.text.trim(),
            'notes': notesC.text.trim(),
          };
          await _postFlexible(isEdit ? 'update_player_match.php' : 'add_player_match.php', payload);
          await _loadMatches(force: true);
          if (mounted) Navigator.pop(context, true);
        },
      ),
    );

    for (final c in [opponentC, dateC, tournamentC, ourScoreC, opponentScoreC, videoC, notesC, ttdC]) {
      c.dispose();
    }
    if (saved == true && mounted) _showSnack(isEdit ? 'Матч обновлён' : 'Матч добавлен');
  }


  // =============================
  // КАЛЕНДАРИ РАЗДЕЛОВ ИГРОКА
  // =============================
  bool _sameDateOnly(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _trainingDateOf(Map<String, dynamic> e) => _parseEventDate(e);

  DateTime? _matchDateOf(Map<String, dynamic> e) {
    final raw = _asStr(e['match_date'] ?? e['date'] ?? e['start_at']).trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceAll(' ', 'T')) ?? _tryParseRuDate(raw);
  }

  DateTime? _diaryDateOf(Map<String, dynamic> e) {
    final raw = _asStr(e['start_at'] ?? e['date'] ?? e['created_at'] ?? e['updated_at']).trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceAll(' ', 'T')) ?? _tryParseRuDate(raw);
  }

  DateTime? _testingDateOf(Map<String, dynamic> e) {
    final raw = _asStr(e['test_date'] ?? e['date']).trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceAll(' ', 'T')) ?? _tryParseRuDate(raw);
  }

  DateTime? _tryParseRuDate(String raw) {
    try {
      return DateFormat('dd.MM.yyyy').parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  Set<String> _markedDays(List<Map<String, dynamic>> items, DateTime? Function(Map<String, dynamic>) dateOf) {
    final out = <String>{};
    for (final item in items) {
      final d = dateOf(item);
      if (d != null) out.add(_dayKey(d));
    }
    return out;
  }

  int _itemsOnDayCount(List<Map<String, dynamic>> items, DateTime? Function(Map<String, dynamic>) dateOf, DateTime day) {
    var count = 0;
    for (final item in items) {
      final d = dateOf(item);
      if (d != null && _sameDateOnly(d, day)) count++;
    }
    return count;
  }

  Widget _buildInlineCalendarHeader({
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onToggle,
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.calendar_month_rounded, color: _AppColors.cmrGreen, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14.2, color: const Color(0xFF101828))),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.6, color: const Color(0xFF667085), weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkedCalendar({
    required List<Map<String, dynamic>> items,
    required DateTime? Function(Map<String, dynamic>) dateOf,
    required DateTime? selectedDay,
    required ValueChanged<DateTime> onSelect,
    DateTime? displayMonth,
    ValueChanged<DateTime>? onMonthChanged,
    bool loading = false,
    Color Function(Map<String, dynamic> item)? markerColorOf,
    void Function(DateTime day, List<Map<String, dynamic>> dayItems)? onDayWithItemsTap,
  }) {
    final now = DateTime.now();
    final base = displayMonth ?? selectedDay ?? now;
    final month = DateTime(base.year, base.month, 1);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return _calendarLikeCmrPanelSize(
      Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.028),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _calendarArrow(
                Icons.chevron_left_rounded,
                () => onMonthChanged != null
                    ? onMonthChanged(DateTime(month.year, month.month - 1, 1))
                    : onSelect(DateTime(month.year, month.month - 1, 1)),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('LLLL yyyy', 'ru').format(month),
                        style: _titleStyle(size: 13.2, color: const Color(0xFF101828)),
                      ),
                      if (loading) ...[
                        const SizedBox(width: 7),
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                ),
              ),
              _calendarArrow(
                Icons.chevron_right_rounded,
                () => onMonthChanged != null
                    ? onMonthChanged(DateTime(month.year, month.month + 1, 1))
                    : onSelect(DateTime(month.year, month.month + 1, 1)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: _bodyStyle(size: 9.6, color: const Color(0xFF667085), weight: FontWeight.w700),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, gridBox) {
              final cellAspect = gridBox.maxWidth >= 680 ? 2.45 : (gridBox.maxWidth >= 520 ? 2.15 : 1.28);
              return GridView.builder(
                itemCount: total,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: cellAspect,
                ),
                itemBuilder: (context, i) {
                  final dayNum = i - leading + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
                  final day = DateTime(month.year, month.month, dayNum);
                  final selected = selectedDay != null && _sameDateOnly(day, selectedDay);
                  final today = _sameDateOnly(day, now);
                  final dayItems = items.where((item) {
                    final d = dateOf(item);
                    return d != null && _sameDateOnly(d, day);
                  }).toList();
                  final count = dayItems.length;
                  final has = count > 0;

                  int coachSum = 0;
                  int coachCnt = 0;
                  int playerSum = 0;
                  int playerCnt = 0;
                  String status = '';

                  final markerColors = <Color>[];
                  for (final item in dayItems) {
                    final st = _attendanceStatusOf(item);
                    if (status.isEmpty || _attendanceStatusPriority(st) > _attendanceStatusPriority(status)) {
                      status = st;
                    }

                    final markerColor = markerColorOf?.call(item) ?? _calendarItemAccent(item);
                    markerColors.add(markerColor);

                    final coach = _firstRatingValue(item, _coachRatingKeys);
                    if (coach != null) {
                      coachSum += _asInt(coach);
                      coachCnt++;
                    }

                    final player = _firstRatingValue(item, _playerRatingKeys);
                    if (player != null) {
                      playerSum += _asInt(player);
                      playerCnt++;
                    }
                  }

                  final int coachAvg = coachCnt == 0
                      ? 0
                      : ((coachSum / coachCnt).round() < 1
                          ? 1
                          : ((coachSum / coachCnt).round() > 5 ? 5 : (coachSum / coachCnt).round()));
                  final int playerAvg = playerCnt == 0
                      ? 0
                      : ((playerSum / playerCnt).round() < 1
                          ? 1
                          : ((playerSum / playerCnt).round() > 5 ? 5 : (playerSum / playerCnt).round()));
                  final accent = markerColors.isNotEmpty ? markerColors.first : const Color(0xFFCBD5E1);

                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        onSelect(day);
                        if (has) onDayWithItemsTap?.call(day, dayItems);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : has
                                  ? _AppColors.softFor(accent)
                                  : _AppColors.cmrSoftPanel,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.055),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (selected)
                              Positioned(
                                left: 0,
                                top: 5,
                                bottom: 5,
                                child: Container(
                                  width: 3,
                                  decoration: BoxDecoration(
                                    color: _AppColors.cmrGreen,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: selected || today ? _AppColors.cmrGreen : const Color(0xFF101828),
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (has)
                              Positioned(
                                top: 2,
                                right: 3,
                                child: _buildCalendarSegmentMarker(markerColors, selected: selected),
                              ),
                            if (has && (coachAvg > 0 || playerAvg > 0))
                              Positioned(
                                left: 5,
                                bottom: 2,
                                child: Text(
                                  [
                                    if (coachAvg > 0) 'Т$coachAvg',
                                    if (playerAvg > 0) 'И$playerAvg',
                                  ].join(' '),
                                  style: TextStyle(
                                    color: selected ? _AppColors.cmrGreen : const Color(0xFF667085),
                                    fontSize: 7.6,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                            if (has)
                              Positioned(
                                right: 4,
                                bottom: 2,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: selected ? _AppColors.cmrGreen : const Color(0xFF667085),
                                    fontSize: 8.2,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  Color _calendarItemAccent(Map<String, dynamic> item) {
    final status = _attendanceStatusOf(item);
    final late = _asInt(item['late_minutes'] ?? item['late'] ?? item['delay_minutes']);
    if (status.isNotEmpty && status != 'unset') {
      return _statusMeta(status, late).color;
    }

    return _trainingCalendarItemAccent(item);
  }

  Color _trainingCalendarItemAccent(Map<String, dynamic> item) {
    final status = _attendanceStatusOf(item);
    final late = _asInt(item['late_minutes'] ?? item['late'] ?? item['delay_minutes']);

    // Если есть проблемная отметка посещаемости — показываем её цветом,
    // иначе используем цвет типа события, как в календаре команды.
    if (_isNegativeAttendance(item)) return _statusMeta(status, late).color;

    final raw = _firstNotEmpty([
      item['event_type'],
      item['eventType'],
      item['calendar_type'],
      item['calendarType'],
      item['training_type'],
      item['trainingType'],
      item['type'],
      item['category'],
      item['kind'],
      item['title'],
      item['event_title'],
      item['name'],
      item['description'],
    ]).trim();

    return _trainingTypeAccent(raw);
  }

  Color _attendanceCalendarItemAccent(Map<String, dynamic> item) {
    final status = _attendanceStatusOf(item);
    final late = _asInt(item['late_minutes'] ?? item['late'] ?? item['delay_minutes']);
    return _statusMeta(status, late).color;
  }

  Widget _buildCalendarSegmentMarker(List<Color> rawColors, {required bool selected}) {
    final colors = rawColors
        .where((c) => c.alpha != 0)
        .take(3)
        .toList(growable: false);

    if (colors.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _CalendarCircleMarkerPainter(
          colors: colors,
          borderColor: selected ? Colors.white : Colors.white,
        ),
        child: rawColors.length > 1
            ? Center(
                child: Text(
                  rawColors.length > 9 ? '9+' : '${rawColors.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    shadows: [
                      Shadow(color: Color(0x66000000), blurRadius: 4),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }




  Widget _calendarArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF334155), size: 20),
      ),
    );
  }

  Widget _buildSelectedDayFilterChip({
    required DateTime date,
    required String label,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_rounded, color: Color(0xFF2563EB), size: 16),
          const SizedBox(width: 7),
          Text('$label: ${DateFormat('dd.MM.yyyy').format(date)}', style: _bodyStyle(size: 11.5, color: const Color(0xFF1D4ED8), weight: FontWeight.w700)),
          const SizedBox(width: 7),
          InkWell(borderRadius: BorderRadius.circular(99), onTap: onClear, child: const Icon(Icons.close_rounded, color: Color(0xFF1D4ED8), size: 16)),
        ],
      ),
    );
  }

  // =============================
  // ТЕСТИРОВАНИЕ ИГРОКА
  // =============================
  String _testingStageCode() {
    final direct = _firstNotEmpty([widget.player['stage'], widget.player['stage_code'], widget.player['category_code'], widget.player['age_group'], widget.player['team_stage']]).toUpperCase();
    final m1 = RegExp(r'U\d{1,2}').firstMatch(direct);
    if (m1 != null) return m1.group(0)!;

    final team = _firstNotEmpty([widget.player['team_name'], widget.player['teamName'], _playerClub()]).toUpperCase();
    final m2 = RegExp(r'U\d{1,2}').firstMatch(team);
    if (m2 != null) return m2.group(0)!;

    final age = int.tryParse(_playerAge()) ?? 0;
    if (age > 0) return 'U$age';
    return 'U13';
  }

  Map<String, dynamic> _decodeResponseMap(String body) {
    final clear = body.trim();
    final idx = clear.indexOf('{');
    if (idx < 0) return {};
    final data = jsonDecode(clear.substring(idx));
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }


  Future<void> _loadPlayerTestingHistory({bool force = false}) async {
    if (playerTestingLoading) return;
    if (!force && playerTestingSessions.isNotEmpty) return;

    setState(() {
      playerTestingLoading = true;
      playerTestingError = null;
      _selectedTestingResultForDetails = null;
    });

    try {
      final stage = _testingStageCode();
      final categories = ['physical', 'technical', 'tactical'];
      final sessionsOut = <Map<String, dynamic>>[];

      for (final category in categories) {
        final uri = Uri.parse('$_apiBase/get_testing_sessions.php').replace(queryParameters: {
          'club_id': '${_asInt(widget.player['club_id'] ?? widget.player['clubId'])}',
          'team_id': '$_teamId',
          'category': category,
          'stage': stage,
        });

        final r = await http.get(uri).timeout(const Duration(seconds: 14));
        final data = _decodeResponseMap(r.body);
        if (data['success'] == true) {
          for (final s in _asMapList(data['sessions'])) {
            sessionsOut.add({...s, 'category': category, 'stage': stage});
          }
        }
      }

      sessionsOut.sort((a, b) => _asStr(b['test_date']).compareTo(_asStr(a['test_date'])));
      DateTime? selected = _selectedTestingDay;
      if (selected == null && sessionsOut.isNotEmpty) selected = _testingDateOf(sessionsOut.first);
      if (_testingCalendarMonth == null && selected != null) {
        _testingCalendarMonth = DateTime(selected.year, selected.month, 1);
      }
      final results = selected == null ? <Map<String, dynamic>>[] : await _loadPlayerTestingResultsForDate(selected, sessionsOut);

      if (!mounted) return;
      setState(() {
        playerTestingSessions = sessionsOut;
        _selectedTestingDay = selected;
        playerTestingResults = results;
        playerTestingLoading = false;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        playerTestingError = '$e';
        playerTestingLoading = false;
      });
      _rebuildOpenSectionSheet();
    }
  }

  String _testingValueText(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      for (final key in const ['value', 'result', 'score', 'points', 'rating']) {
        if (raw.containsKey(key) && raw[key] != null) {
          final nested = _testingValueText(raw[key]);
          if (nested.trim().isNotEmpty && nested != 'null') return nested;
        }
      }
      return '';
    }
    final text = _asStr(raw).trim();
    if (text.isEmpty || text == 'null') return '';
    if (text.startsWith('{')) {
      final m = RegExp(r'value:\s*([^,}]+)').firstMatch(text);
      if (m != null) return _testingValueText((m.group(1) ?? '').trim());
      final p = RegExp(r'points:\s*([^,}]+)').firstMatch(text);
      if (p != null) return _testingValueText((p.group(1) ?? '').trim());
      return '';
    }
    final normalized = text.replaceAll(',', '.');
    final number = double.tryParse(normalized);
    if (number != null) {
      if (number == number.roundToDouble()) return number.toStringAsFixed(0);
      return number.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  String _testingCategoryTitle(String category) {
    switch (category) {
      case 'physical': return 'Физика';
      case 'technical': return 'Техника';
      case 'tactical': return 'Тактика';
      default: return category.isEmpty ? '—' : category;
    }
  }

  Future<List<Map<String, dynamic>>> _loadPlayerTestingResultsForDate(DateTime date, List<Map<String, dynamic>> sessions) async {
    final playerId = await _resolvePlayerId();
    final out = <Map<String, dynamic>>[];
    final iso = _fmtYmd(date);

    for (final s in sessions) {
      final sessionDate = _testingDateOf(s);
      if (sessionDate == null || !_sameDateOnly(sessionDate, date)) continue;
      final category = _asStr(s['category']).isEmpty ? 'physical' : _asStr(s['category']);
      final stage = _asStr(s['stage']).isEmpty ? _testingStageCode() : _asStr(s['stage']);
      final sessionId = _asInt(s['id']);

      final uri = Uri.parse('$_apiBase/get_testing_matrix.php').replace(queryParameters: {
        'club_id': '${_asInt(widget.player['club_id'] ?? widget.player['clubId'])}',
        'team_id': '$_teamId',
        'category': category,
        'stage': stage,
        'test_date': iso,
        if (sessionId > 0) 'session_id': '$sessionId',
      });

      final r = await http.get(uri).timeout(const Duration(seconds: 14));
      final data = _decodeResponseMap(r.body);
      if (data['success'] != true) continue;

      final tests = _asMapList(data['tests']);
      final players = _asMapList(data['players']);
      for (final p in players) {
        final pid = _asInt(p['player_id'] ?? p['id'] ?? p['user_id']);
        if (pid != playerId) continue;

        final results = p['results'];
        if (results is Map) {
          results.forEach((code, rawValue) {
            final test = tests.firstWhere((t) => _asStr(t['code']) == _asStr(code), orElse: () => <String, dynamic>{});
            final value = _testingValueText(rawValue);
            if (value.trim().isEmpty) return;
            out.add({
              'title': _firstNotEmpty([test['title'], test['name'], code]),
              'code': _asStr(code),
              'value': value,
              'unit': _asStr(test['unit']),
              'category': category,
              'stage': stage,
              'date': iso,
              'status': rawValue is Map ? _firstNotEmpty([rawValue['status'], rawValue['grade'], rawValue['level'], rawValue['result_status']]) : '',
              'rating': rawValue is Map ? _firstNotEmpty([rawValue['rating'], rawValue['score'], rawValue['points']]) : '',
              'passed': rawValue is Map ? rawValue['passed'] : null,
              'direction': _firstNotEmpty([test['direction'], test['better'], test['better_when'], test['score_direction']]),
              'norm_min': _firstNotEmpty([test['norm_min'], test['min_norm'], test['good_min'], test['min_value'], test['min']]),
              'norm_max': _firstNotEmpty([test['norm_max'], test['max_norm'], test['good_max'], test['max_value'], test['max']]),
              'bad_min': _firstNotEmpty([test['bad_min'], test['critical_min'], test['red_min']]),
              'bad_max': _firstNotEmpty([test['bad_max'], test['critical_max'], test['red_max']]),
            });
          });
        }
      }
    }

    return out;
  }

  Future<void> _selectPlayerTestingDate(DateTime date) async {
    setState(() {
      _selectedTestingDay = DateTime(date.year, date.month, date.day);
      _testingCalendarMonth = DateTime(date.year, date.month, 1);
      playerTestingLoading = true;
      playerTestingError = null;
    });
    _rebuildOpenSectionSheet();

    try {
      final rows = await _loadPlayerTestingResultsForDate(_selectedTestingDay!, playerTestingSessions);
      if (!mounted) return;
      setState(() {
        playerTestingResults = rows;
        _selectedTestingResultForDetails = rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
        playerTestingLoading = false;
      });
      _rebuildOpenSectionSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        playerTestingError = '$e';
        playerTestingLoading = false;
      });
      _rebuildOpenSectionSheet();
    }
  }

  Widget _buildTestingHistoryTab() {
    final splitMode = _isWideSplitDetailsMode();

    return _buildCmrSectionShell(
      title: 'Тестирование игрока',
      subtitle: 'Реальные даты тестов игрока, результаты по выбранному дню и быстрый контроль динамики',
      icon: Icons.fact_check_rounded,
      stats: [
        _buildCmrMiniStat('Даты', '${playerTestingSessions.length}', Icons.event_available_outlined),
        _buildCmrMiniStat('Показатели', '${playerTestingResults.length}', Icons.speed_rounded),
        _buildCmrMiniStat('Этап', _testingStageCode(), Icons.flag_outlined),
        _buildCmrMiniStat('Календарь', _testingCalendarExpanded ? 'Открыт' : 'Свернут', Icons.calendar_month_outlined),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () async {
          await _loadPlayerTestingHistory(force: true);
          _rebuildOpenSectionSheet();
        }),
      ],
      children: [
        if (!splitMode)
          _buildInlineCalendarHeader(
            title: 'Календарь тестирования',
            subtitle: 'Листайте месяцы, выбирайте дату — результаты обновятся внутри этого окна.',
            expanded: _testingCalendarExpanded,
            onToggle: () async {
              _safeSetState(() => _testingCalendarExpanded = !_testingCalendarExpanded);
              if (_testingCalendarExpanded && playerTestingSessions.isEmpty && !playerTestingLoading) {
                await _loadPlayerTestingHistory(force: true);
              }
              _rebuildOpenSectionSheet();
            },
          ),
        if (splitMode || _testingCalendarExpanded) ...[
          if (!splitMode) const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: playerTestingSessions,
            dateOf: _testingDateOf,
            selectedDay: _selectedTestingDay,
            displayMonth: _testingCalendarMonth ?? _selectedTestingDay ?? DateTime.now(),
            onMonthChanged: (month) {
              _safeSetState(() => _testingCalendarMonth = month);
            },
            onSelect: _selectPlayerTestingDate,
            loading: playerTestingLoading,
          ),
        ],
        if (_selectedTestingDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(date: _selectedTestingDay!, label: 'Выбрана дата тестирования', onClear: () => _safeSetState(() { _selectedTestingDay = null; playerTestingResults = []; })),
        ],
        const SizedBox(height: 12),
        if (playerTestingLoading)
          _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator())))
        else if (playerTestingError != null)
          _buildEmptyState(icon: Icons.error_outline_rounded, message: playerTestingError!, action: TextButton(onPressed: () => _loadPlayerTestingHistory(force: true), child: const Text('Повторить')))
        else if (playerTestingSessions.isEmpty)
          _buildEmptyState(icon: Icons.fact_check_outlined, message: 'По игроку пока нет дат тестирования.')
        else if (_isWideSplitDetailsMode())
          _buildTestingSplitHintCard()
        else if (playerTestingResults.isEmpty)
          _buildEmptyState(icon: Icons.info_outline_rounded, message: 'На выбранную дату результаты игрока не найдены.')
        else
          _buildTestingResultsTable(playerTestingResults),
      ],
    );
  }

  Widget _buildTestingSplitHintCard() {
    final date = _selectedTestingDay;
    final warningCount = playerTestingResults.where(_isTestingResultPoor).length;
    return _buildCmrCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: warningCount > 0 ? _AppColors.redSoft : _AppColors.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              warningCount > 0 ? Icons.warning_amber_rounded : Icons.fact_check_rounded,
              color: warningCount > 0 ? _AppColors.error : _AppColors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Результаты показываются справа', style: _titleStyle(size: 15, color: const Color(0xFF101828))),
                const SizedBox(height: 4),
                Text(
                  date == null
                      ? 'Выберите дату тестирования в календаре.'
                      : warningCount > 0
                          ? 'За ${DateFormat('dd.MM.yyyy').format(date)}: ${playerTestingResults.length} показателей, $warningCount требуют внимания.'
                          : 'За ${DateFormat('dd.MM.yyyy').format(date)}: ${playerTestingResults.length} показателей. Подробности без дублей находятся в правом блоке.',
                  style: _bodyStyle(size: 12, color: warningCount > 0 ? _AppColors.error : const Color(0xFF667085), weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingResultsTable(List<Map<String, dynamic>> rows) {
    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _AppColors.blueSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.speed_rounded, color: _AppColors.blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Результаты выбранной даты', style: _titleStyle(size: 15, color: const Color(0xFF101828))),
                    const SizedBox(height: 2),
                    Text('${rows.length} показателей по игроку', style: _bodyStyle(size: 11.8, color: const Color(0xFF667085), weight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final twoCols = c.maxWidth >= 620;
              if (!twoCols) {
                return Column(children: rows.map(_buildTestingResultTile).toList());
              }
              final width = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: rows.map((r) => SizedBox(width: width, child: _buildTestingResultTile(r))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTestingResultTile(Map<String, dynamic> r) {
    final unit = _asStr(r['unit']);
    final baseValue = _testingValueText(r['value']);
    final value = '${baseValue.isEmpty ? '—' : baseValue}${unit.isEmpty || baseValue.isEmpty ? '' : ' $unit'}';
    final category = _testingCategoryTitle(_asStr(r['category']));
    final selected = identical(_selectedTestingResultForDetails, r) ||
        (_selectedTestingResultForDetails != null &&
            _asStr(_selectedTestingResultForDetails!['id']) == _asStr(r['id']) &&
            _asStr(r['id']).isNotEmpty);
    return Material(
      color: selected ? Colors.white : _AppColors.cmrSoftPanel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() => _selectedTestingResultForDetails = Map<String, dynamic>.from(r));
          _rebuildOpenSectionSheet();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: selected ? _AppColors.cmrSoft : _AppColors.blueSoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.fact_check_rounded, color: _AppColors.blue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_asStr(r['title']), maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 13.2, color: const Color(0xFF101828), weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.4, color: const Color(0xFF101828), weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    final playerName = _asStr(widget.player['fullName'] ?? widget.player['full_name'] ?? widget.player['name']).trim();
    return _buildCmrSectionShell(
      title: 'Экспорт данных игрока',
      subtitle: 'PDF-карточка с отметкой «Спортотека»: профиль, метрики, медкарта, тренировки, матчи и дневник.',
      icon: Icons.picture_as_pdf_rounded,
      stats: [
        _buildCmrMiniStat('Метрики', '${metrics.length}', Icons.query_stats_rounded),
        _buildCmrMiniStat('Медкарта', '${medicalRecords.length}', Icons.health_and_safety_outlined),
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_score_outlined),
        _buildCmrMiniStat('Дневник', '${diaryItems.length}', Icons.menu_book_outlined),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.file_download_outlined, label: 'Выгрузить PDF', onTap: _exportPlayerPdf),
      ],
      children: [
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF178A45), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playerName.isEmpty ? 'Карточка игрока' : playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 18, color: const Color(0xFF101828))),
                        const SizedBox(height: 4),
                        Text('PDF будет сформирован с шапкой «Спортотека» и основными разделами профиля.', style: _bodyStyle(size: 12.5, color: const Color(0xFF667085), weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _ExportBadge('Профиль'),
                  _ExportBadge('Метрики'),
                  _ExportBadge('Достижения'),
                  _ExportBadge('Медиа'),
                  _ExportBadge('Медкарта'),
                  _ExportBadge('Тренировки'),
                  _ExportBadge('Матчи'),
                  _ExportBadge('Дневник'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportPlayerPdf() async {
    final playerId = await _resolvePlayerId();
    if (playerId <= 0) {
      _showSnack('Не удалось определить игрока для PDF');
      return;
    }
    final uri = Uri.parse('$_apiBase/export_player_pdf.php').replace(queryParameters: {
      'player_id': '$playerId',
      'team_id': '$_teamId',
      'brand': 'Спортотека',
      'format': 'pdf',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _savePlayerField(Map<String, String> fields) async {
    final playerId = await _resolvePlayerId();
    final payload = <String, String>{
      'id': '$playerId',
      'player_id': '$playerId',
      'team_id': '$_teamId',
      ...fields,
    };
    await _postFlexible('update_player.php', payload);
  }

  Future<void> _savePlayerEditorFields(Map<String, String> fields) async {
    await _savePlayerField(fields);
    widget.player.addAll(fields);
    _parseSportData();
    _parseMedia();
    if (mounted) setState(() {});
    _rebuildOpenSectionSheet();
  }

  Future<Map<String, dynamic>> _postFlexible(String endpoint, Map<String, String> body) async {
    final res = await http.post(Uri.parse('$_apiBase/$endpoint'), body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Ошибка сервера ${res.statusCode}');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final ok = decoded['success'] == true || decoded['status'] == 'success' || decoded['ok'] == true;
        if (!ok && decoded.containsKey('message')) throw Exception(decoded['message'].toString());
        return decoded;
      }
    } catch (_) {}
    return {'success': true};
  }

  Widget _buildTinyEditorButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF178A45)),
            const SizedBox(width: 6),
            Text(label, style: _bodyStyle(size: 11.5, color: const Color(0xFF334155), weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    required Future<void> Function() onSave,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: _AppColors.cmrBorder, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: const Color(0xFFEAF5EE), borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: const Color(0xFF178A45), size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _titleStyle(size: 18, color: const Color(0xFF101828))),
                        const SizedBox(height: 3),
                        Text(subtitle, style: _bodyStyle(size: 12, color: const Color(0xFF667085), weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCmrCard(child: child),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF178A45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  // =============================
  // COMMON UI
  // =============================
 Widget _noteBox({
  required IconData icon,
  required String title,
  required String text,
  bool subtleWhenEmpty = false,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _primary.withOpacity(subtleWhenEmpty ? 0.03 : 0.04),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  fontSize: 10.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 10.6,
                  height: 1.3,
                  color: subtleWhenEmpty ? _textSecondary : _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _pillInfo(IconData icon, String title, String value, {Color? color}) {
    final c = color ?? _primary;
    final wide = MediaQuery.of(context).size.width >= 720;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 13 : 8, vertical: wide ? 9 : 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(wide ? 24 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: wide ? 17 : 12, color: c),
          SizedBox(width: wide ? 7 : 4),
          Text(
            "$title: ",
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: wide ? 12.4 : 10,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: wide ? 12.4 : 10,
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSectionBanner({
  required String title,
  required String subtitle,
  required IconData icon,
  required int count,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _titleStyle(size: 14, color: _textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: _bodyStyle(size: 10, color: _textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              color: _primary,
              fontSize: 11.2,
            ),
          ),
        ),
      ],
    ),
  );
}

 Widget _buildInfoCard({
  required String title,
  required IconData icon,
  required List<Widget> children,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(_design.cardRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: _titleStyle(size: 15, color: _textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

  Widget _buildInfoRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 42, child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, color: _AppColors.textSecondary, height: 1.2, fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(flex: 58, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.7, color: _AppColors.textPrimary, height: 1.28, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildEmptyState({
  required IconData icon,
  required String message,
  Widget? action,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(
          message,
          style: _bodyStyle(size: 12, color: _textSecondary),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          action,
        ],
      ],
    ),
  );
}

    void _showAddMedicalRecordDialog() {
    _showMedicalRecordEditorSheet();
  }

  void _showEditMedicalRecordDialog(Map<String, dynamic> record) {
    _showMedicalRecordEditorSheet(record: record);
  }

  void _showMedicalRecordEditorSheet({Map<String, dynamic>? record}) {
    if (_usesCmrRightDetailsPane(context)) {
      _openRightEditor(_CmrRightEditorMode.medicalRecord, medicalRecord: record);
      return;
    }

    final isEdit = record != null;
    final typeController = TextEditingController(text: isEdit ? _asStr(record?['type']) : '');
    final titleController = TextEditingController(text: isEdit ? _asStr(record?['title']) : '');
    final valueController = TextEditingController(text: isEdit ? _asStr(record?['value']) : '');
    final commentController = TextEditingController(text: isEdit ? _asStr(record?['comment']) : '');
    DateTime selectedDate = DateTime.tryParse(isEdit ? _asStr(record?['date']) : '') ?? DateTime.now();
    XFile? selectedFile;
    bool isUploading = false;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxHeight = screenHeight * 0.92;

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: _AppColors.primaryGreen,
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() => selectedDate = picked);
              }
            }

            Future<void> pickFile({required bool imageOnly}) async {
              final picker = ImagePicker();
              final file = imageOnly
                  ? await picker.pickImage(source: ImageSource.gallery)
                  : await picker.pickMedia();
              if (file != null) {
                setModalState(() => selectedFile = file);
              }
            }

            Future<void> saveRecord() async {
              final type = typeController.text.trim();
              final title = titleController.text.trim();
              final value = valueController.text.trim();
              final comment = commentController.text.trim();

              if (title.isEmpty && value.isEmpty) {
                _showSnack('Заполните название или описание записи');
                return;
              }

              setModalState(() => isUploading = true);

              try {
                final uri = Uri.parse(
                  isEdit
                      ? '$_apiBase/medical/update_record.php'
                      : '$_apiBase/medical/add_record.php',
                );
                final request = http.MultipartRequest('POST', uri);

                if (isEdit) {
                  request.fields['id'] = _asStr(record?['id']);
                } else {
                  request.fields['user_id'] = widget.player['user_id'].toString();
                }

                request.fields['type'] = type.isEmpty ? 'Запись' : type;
                request.fields['title'] = title;
                request.fields['value'] = value;
                request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                request.fields['comment'] = comment;

                if (selectedFile != null) {
                  request.files.add(
                    await http.MultipartFile.fromPath('file', selectedFile!.path),
                  );
                }

                final response = await request.send();
                final responseBody = await response.stream.bytesToString();

                bool success = response.statusCode == 200;
                String? serverMessage;

                try {
                  final decoded = jsonDecode(responseBody);
                  if (decoded is Map) {
                    success = decoded['success'] == true || decoded['status'] == 'success' || response.statusCode == 200;
                    serverMessage = _asStr(decoded['message'] ?? decoded['error']);
                  }
                } catch (_) {
                  // Сервер иногда возвращает не JSON. В этом случае ориентируемся на statusCode.
                }

                if (!mounted) return;

                if (success) {
                  Navigator.of(sheetContext).pop();
                  _showSnack(isEdit ? 'Медицинская запись обновлена' : 'Медицинская запись добавлена');
                  _loadMedicalRecords();
                } else {
                  setModalState(() => isUploading = false);
                  _showSnack(serverMessage?.isNotEmpty == true ? serverMessage! : 'Не удалось сохранить запись');
                }
              } catch (e) {
                debugPrint('Error saving medical record: $e');
                if (!mounted) return;
                setModalState(() => isUploading = false);
                _showSnack('Ошибка сохранения: $e');
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _AppColors.cmrBorder,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: _buildMedicalEditorHeader(
                            title: isEdit ? 'Редактор медзаписи' : 'Новая медзапись',
                            subtitle: isEdit
                                ? 'Обновите данные осмотра, травмы или рекомендации.'
                                : 'Добавьте осмотр, травму, справку или рекомендацию врача.',
                            onClose: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMedicalEditorSection(
                                  title: 'Тип записи',
                                  icon: Icons.category_rounded,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildMedicalTypeChip('Осмотр', typeController, setModalState),
                                          _buildMedicalTypeChip('Травма', typeController, setModalState),
                                          _buildMedicalTypeChip('Вакцинация', typeController, setModalState),
                                          _buildMedicalTypeChip('Справка', typeController, setModalState),
                                          _buildMedicalTypeChip('Рекомендация', typeController, setModalState),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildMedicalEditorInput(
                                        controller: typeController,
                                        hint: 'Можно указать свой тип',
                                        icon: Icons.edit_note_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMedicalEditorSection(
                                  title: 'Основная информация',
                                  icon: Icons.medical_information_rounded,
                                  child: Column(
                                    children: [
                                      _buildMedicalEditorInput(
                                        controller: titleController,
                                        hint: 'Название: медосмотр, справка, травма...',
                                        icon: Icons.title_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _buildMedicalEditorInput(
                                        controller: valueController,
                                        hint: 'Описание / значение',
                                        icon: Icons.notes_rounded,
                                        minLines: 3,
                                        maxLines: 5,
                                      ),
                                      const SizedBox(height: 10),
                                      _buildMedicalEditorInput(
                                        controller: commentController,
                                        hint: 'Комментарий тренера или врача',
                                        icon: Icons.chat_bubble_outline_rounded,
                                        minLines: 2,
                                        maxLines: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMedicalEditorSection(
                                  title: 'Дата и вложения',
                                  icon: Icons.event_available_rounded,
                                  child: Column(
                                    children: [
                                      _buildMedicalDateCard(
                                        date: selectedDate,
                                        onTap: pickDate,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildMedicalAttachButton(
                                              icon: Icons.image_rounded,
                                              title: 'Фото',
                                              subtitle: 'Из галереи',
                                              onTap: () => pickFile(imageOnly: true),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildMedicalAttachButton(
                                              icon: Icons.attach_file_rounded,
                                              title: 'Файл',
                                              subtitle: 'PDF / DOC',
                                              onTap: () => pickFile(imageOnly: false),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (selectedFile != null) ...[
                                        const SizedBox(height: 10),
                                        _buildSelectedMedicalFileCard(
                                          fileName: selectedFile!.name,
                                          onClear: () => setModalState(() => selectedFile = null),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            14 + MediaQuery.of(context).padding.bottom,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isUploading ? null : () => Navigator.of(sheetContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _AppColors.textPrimary,
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text(
                                    'Отмена',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: isUploading ? null : saveRecord,
                                  icon: isUploading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, size: 20),
                                  label: Text(isEdit ? 'Сохранить изменения' : 'Добавить запись'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicalEditorHeader({
    required String title,
    required String subtitle,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: _AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 14.6,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.close_rounded, color: _AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalEditorSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _AppColors.primaryGreen, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMedicalTypeChip(
    String label,
    TextEditingController controller,
    void Function(void Function()) setModalState,
  ) {
    final active = controller.text.trim().toLowerCase() == label.toLowerCase();
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => setModalState(() => controller.text = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _AppColors.textPrimary,
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalEditorInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        color: _AppColors.textPrimary,
        fontSize: 12.6,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 11.7, fontWeight: FontWeight.w600),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, color: _AppColors.textSecondary, size: 19),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMedicalDateCard({
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _AppColors.primaryGreen.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.calendar_today_rounded, color: _AppColors.primaryGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Дата записи',
                    style: TextStyle(color: _AppColors.textSecondary, fontSize: 10.6, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd.MM.yyyy').format(date),
                    style: const TextStyle(color: _AppColors.textPrimary, fontSize: 12.6, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalAttachButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 22),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AppColors.textPrimary, fontSize: 11.7, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AppColors.textSecondary, fontSize: 10.6, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMedicalFileCard({
    required String fileName,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.primaryGreen.withOpacity(.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _AppColors.primaryGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AppColors.textPrimary, fontSize: 11.2, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18, color: _AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String hint) {
    return _buildMedicalEditorInput(
      controller: controller,
      hint: hint,
      icon: Icons.edit_note_rounded,
    );
  }


  Future<void> _assignTraining() async {
    final playerId = widget.player['user_id'];
    if (playerId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddTrainingScreen(playerId: playerId)),
      );
      if (!mounted) return;
      await _loadTrainingSectionData(force: true);
    }
  }

  Future<void> _refreshCmrProfile() async {
  _loadMedicalRecords();
  _parseSportData();
  _parseMedia();
  await _loadDesignFromServer();


  if (_selectedTabIndex == 4 || _selectedTabIndex == 54) {
    await _loadTrainingSectionData(force: true);
  }

  if (_selectedTabIndex == 5) await _loadMatches(force: true);
  if (_selectedTabIndex == 7) await _loadPlayerTestingHistory(force: true);
  
  // **ВАЖНО: Если есть выбранная тренировка, перезагружаем её данные**
  if (selectedEvent != null) {
    final eventId = _trainingRowEventId(selectedEvent!);
    if (eventId > 0) {
      await _loadPlayerInfoForEvent(eventId);
    }
  }
  
  _rebuildOpenSectionSheet();
}


  Future<void> _selectCmrTab(int index) async {
    setState(() {
      _selectedTabIndex = index;
      _rightEditorMode = null;
      _rightEditorMedicalRecord = null;
    });

    if (index == 7) {
      await _loadPlayerTestingHistory(force: false);
    }

    if (index == 4 || index == 52 || index == 54) {
      await _loadTrainingSectionData(force: true);
      if (attendanceLog.isEmpty && !attendanceLoading) {
        await _loadAttendanceLog(force: false);
      }
    }

    if (index == 5 || index == 50) await _loadMatches();
    _rebuildOpenSectionSheet();
  }

  String _cmrFullName() {
    final full = _firstNotEmpty([
      widget.player["fullName"],
      widget.player["full_name"],
      widget.player["name"],
    ]);
    if (full.isNotEmpty) return full;

    final first = _firstNotEmpty([widget.player["first_name"], widget.player["firstname"]]);
    final last = _firstNotEmpty([widget.player["last_name"], widget.player["lastname"]]);
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Игрок' : name;
  }


  Color _cmrTabAccent(int index) {
    switch (index) {
      case 0:
        return _AppColors.cmrGreen;
      case 1:
        return _AppColors.cmrGreen;
      case 2:
        return _AppColors.orange;
      case 3:
        return _AppColors.cmrGreen;
      case 4:
        return _AppColors.orange;
      case 5:
        return _AppColors.blue;
      case 7:
        return _AppColors.orange;
      case 8:
        return _AppColors.blue;
      case 50:
        return _AppColors.cmrGreen;
      case 51:
        return _AppColors.blue;
      case 52:
        return _AppColors.cmrGreen;
      case 54:
        return _AppColors.blue;
      default:
        return _AppColors.cmrGreen;
    }
  }

  Color _cmrTabSoft(int index) => _AppColors.softFor(_cmrTabAccent(index));

  void _openPlayerEditorPanel() {
    final isTablet = MediaQuery.of(context).size.width >= 720;
    if (!isTablet) {
      Get.toNamed(AppRoutes.editPlayerScreen, arguments: widget.player)?.then((_) {
        if (mounted) _refreshCmrProfile();
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedTabIndex = 0;
      _showInlinePlayerEditor = true;
    });
  }

  Future<void> _closePlayerEditorPanel({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _showInlinePlayerEditor = false);
    if (refresh) {
      await _refreshCmrProfile();
    }
  }

  void _closePlayerProfileScreen() {
    _exitPlayerProfileToHome();
  }

  void _exitPlayerProfileToHome() {
    if (!mounted) return;

    // В CMR-окне кнопка X означает не закрыть внутренний блок,
    // а выйти из профиля к начальному экрану приложения.
    try {
      Get.offAllNamed('/home_screen');
      return;
    } catch (_) {
      // Если в проекте используется другой route name — мягко возвращаемся
      // к первому экрану текущего навигатора.
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.popUntil((route) => route.isFirst);
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Widget _buildCmrProfileExitButton({required bool compact}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _closePlayerProfileScreen,
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14, vertical: compact ? 10 : 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF667085)),
                ),
                if (!compact) ...[
                  const SizedBox(width: 9),
                  const Text('Закрыть профиль', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF101828), fontSize: 11.7, fontWeight: FontWeight.w600, height: 1)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrShellSidebar({required bool compact}) {
    // Меню профиля теперь повторяет визуальный принцип трекера:
    // открытая рабочая панель слева, без кнопок свернуть/развернуть профиль внутри меню.
    final expanded = !compact;
    final railWidth = compact ? 54.0 : 156.0;
    final photo = _normalizeImage(widget.player['photo']);
    final name = _cmrFullName();
    final team = _firstNotEmpty([
      widget.player['team_name'],
      widget.player['teamName'],
      widget.player['club'],
      widget.player['club_name'],
    ]);

    return Container(
      width: railWidth,
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(expanded ? 9 : 6, 12, expanded ? 8 : 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlayerSidebarLogoHeader(
            compact: !expanded,
            photo: photo,
            name: name,
            team: team,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _categoryTabs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final tab = _categoryTabs[index];
                final active = tab.index == _selectedTabIndex;
                final tile = _buildPlayerSidebarTab(
                  tab: tab,
                  active: active,
                  accent: _AppColors.cmrGreen,
                  compact: !expanded,
                );
                return Tooltip(
                  message: expanded ? '' : tab.title,
                  waitDuration: const Duration(milliseconds: 250),
                  preferBelow: false,
                  child: tile,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _buildPlayerSidebarFooterAction(
            icon: Icons.refresh_rounded,
            label: 'Обновить',
            compact: !expanded,
            onTap: _refreshCmrProfile,
          ),
          const SizedBox(height: 6),
          _buildPlayerSidebarFooterAction(
            icon: Icons.edit_rounded,
            label: 'Редактировать',
            compact: !expanded,
            onTap: _openPlayerEditorPanel,
          ),
        ],
      ),
    );
  }


  Widget _buildPlayerSidebarWindowControls({required bool expanded}) {
    return const SizedBox.shrink();
  }


  Widget _buildCmrSidebarMiniControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      child: Material(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFF0F2F4), width: 1),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }



  Widget _buildPlayerSidebarHeader({
    required bool compact,
    required String photo,
    required String name,
    required String team,
    required String position,
  }) {
    return _buildPlayerSidebarLogoHeader(compact: compact, photo: photo, name: name, team: team);
  }

  Widget _buildPlayerSidebarLogoHeader({
    required bool compact,
    required String? photo,
    required String name,
    required String team,
  }) {
    if (compact) {
      return Center(child: _buildPlayerSidebarLogo(photo: photo, size: 38));
    }

    return Row(
      children: [
        _buildPlayerSidebarLogo(photo: photo, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Профиль игрока' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: const Color(0xFF0B0F14),
                  fontSize: 12.0,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.18,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                team.isEmpty ? 'Игрок' : team,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: const Color(0xFF6B7280),
                  fontSize: 9.6,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSidebarLogo({required String? photo, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F2F4), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: (photo ?? '').trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 20)
          : _buildCircleNetworkImage(
              imageUrl: photo,
              size: size,
              borderColor: Colors.transparent,
              borderWidth: 0,
              fallback: const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 20),
            ),
    );
  }

  Widget _buildPlayerSidebarFooterAction({
    required IconData icon,
    required String label,
    required bool compact,
    required VoidCallback onTap,
  }) {
    if (compact) {
      return _buildCmrSidebarIconButton(icon: icon, tooltip: label, onTap: onTap);
    }

    return Material(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6B7280), size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: const Color(0xFF344054),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.12,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildTrainerLikePill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AppColors.textSecondary, fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSidebarStatusCard() {
    return const SizedBox.shrink();
  }


  Widget _buildPlayerSidebarTab({
    required _CategoryTab tab,
    required bool active,
    required Color accent,
    required bool compact,
  }) {
    final bgColor = active ? const Color(0xFFF3FBF7) : Colors.transparent;
    final iconColor = active ? _AppColors.cmrGreen : const Color(0xFF6B7280);
    final textColor = active ? const Color(0xFF0B0F14) : const Color(0xFF344054);

    if (compact) {
      return Material(
        color: active ? const Color(0xFFF3FBF7) : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleCmrSidebarTabTap(tab),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: active ? Border.all(color: const Color(0xFFDCEFE5), width: 1) : null,
            ),
            child: Icon(tab.icon, color: iconColor, size: 18),
          ),
        ),
      );
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleCmrSidebarTabTap(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 34,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: active ? Border.all(color: const Color(0xFFDCEFE5), width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(tab.icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: textColor,
                    fontSize: 10.8,
                    height: 1,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -.12,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCmrSidebarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color background = const Color(0xFFF4F6F8),
    Color foreground = const Color(0xFF667085),
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12.2, height: 1))),
          ]),
        ),
      ),
    );
  }


  Widget _buildCmrSidebarIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String tooltip = 'Действие',
    Color background = const Color(0xFFF5F7FA),
    Color foreground = const Color(0xFF6B7280),
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFF0F2F4), width: 1),
            ),
            child: Icon(icon, color: foreground, size: 18),
          ),
        ),
      ),
    );
  }




  Widget _buildCmrTabletWorkspace({required bool compact}) {
    final tab = _categoryTabs.firstWhere((e) => e.index == _selectedTabIndex, orElse: () => _categoryTabs.first);

    final workspace = _showInlinePlayerEditor
        ? _buildCmrWorkspaceWithInlineEditor(tab: tab, compact: compact)
        : _buildCmrWorkspaceContent(tab: tab, compact: compact);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: workspace,
    );
  }

  Widget _buildCmrWorkspaceContent({required _CategoryTab tab, required bool compact}) {
    if (tab.index == 0) {
      return _buildOverviewDashboardWorkspace(compact: compact);
    }

    // Единая CMR-сетка: слева фиксированная рабочая колонка
    // (список / календарь / выбор), справа — широкая область деталей.
    if (!_usesCmrRightDetailsPane(context) || _showInlinePlayerEditor) {
      final guideWidth = _cmrGuideCollapsed ? (compact ? 56.0 : 64.0) : (compact ? 300.0 : 340.0);
      return Row(
        key: ValueKey('player-workspace-tab-${tab.index}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: guideWidth, child: _buildCmrCenterPane(tab)),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE8EDF2)),
          Expanded(child: _buildCmrDetailsPane(tab)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
        final targetLeftWidth = compact ? 470.0 : 500.0;
        final leftWidth = math.min(targetLeftWidth, math.max(420.0, totalWidth * .42));

        return Row(
          key: ValueKey('player-workspace-split-tab-${tab.index}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: _buildCmrDetailsPane(tab)),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE8EDF2)),
            Expanded(child: _buildCmrSelectionDetailsPane(tab)),
          ],
        );
      },
    );
  }


  Future<void> _selectTrainingForDetails(Map<String, dynamic> raw, {bool loadInfo = true}) async {
  final e = _enrichTrainingRecord(Map<String, dynamic>.from(raw));
  final d = _parseEventDate(e);
  final id = _trainingRowEventId(e);
  
  if (!mounted) return;
  
  setState(() {
    selectedEvent = e;
    selectedEventPlayerInfo = null;
    if (d != null) {
      _selectedTrainingDay = DateTime(d.year, d.month, d.day);
      _eventFilterDate = _selectedTrainingDay;
      _trainingCalendarMonth = DateTime(d.year, d.month, 1);
    }
  });
  
  _rebuildOpenSectionSheet();
  
  if (loadInfo && id > 0) {
    await _loadPlayerInfoForEvent(id);
    _rebuildOpenSectionSheet();
  }
}

  Future<void> _selectMatchForDetails(Map<String, dynamic> raw, {bool loadTtd = false}) async {
    final m = Map<String, dynamic>.from(raw);
    final d = _matchDateOf(m);
    final matchId = _asInt(m['match_id'] ?? m['id']);
    if (!mounted) return;
    setState(() {
      selectedTtdMatch = m;
      if (d != null) {
        _selectedMatchDay = DateTime(d.year, d.month, d.day);
        _matchesCalendarMonth = DateTime(d.year, d.month, 1);
      }
      if (loadTtd && matchId > 0) {
        _openingPlayerMatchId = matchId;
      } else {
        playerTtdLoading = false;
        playerTtdError = null;
        playerTtdSummary = {};
        playerTtdMainRows = [];
        playerTtdPassRows = [];
        playerTtdGoalkeeperRows = [];
      }
    });
    _rebuildOpenSectionSheet();
    if (loadTtd && matchId > 0) {
      await _loadPlayerTtdForMatch(m);
      if (mounted) {
        setState(() => _openingPlayerMatchId = 0);
        _rebuildOpenSectionSheet();
      }
    }
  }

  Map<String, dynamic>? _trainingDetailsSelection() {
    if (selectedEvent != null) {
      final out = _enrichTrainingRecord(Map<String, dynamic>.from(selectedEvent!));
      if (selectedEventPlayerInfo != null && selectedEventPlayerInfo?['error'] == null) {
        _mergeTrainingCandidate(out, Map<String, dynamic>.from(selectedEventPlayerInfo!));
      }
      return _enrichTrainingRecord(out);
    }
    final all = _dedupeAndEnrichTrainingRows([...teamEvents, ...attendanceLog]);
    final day = _selectedTrainingDay ?? _eventFilterDate;
    if (day != null) {
      for (final item in all) {
        final d = _parseEventDate(item);
        if (d != null && _sameDateOnly(d, day)) return item;
      }
    }
    return all.isEmpty ? null : all.first;
  }

  Map<String, dynamic>? _matchDetailsSelection() {
    if (selectedTtdMatch != null) return Map<String, dynamic>.from(selectedTtdMatch!);
    final day = _selectedMatchDay;
    if (day != null) {
      for (final item in matches) {
        final d = _matchDateOf(item);
        if (d != null && _sameDateOnly(d, day)) return item;
      }
    }
    return matches.isEmpty ? null : Map<String, dynamic>.from(matches.first);
  }

  String? _metricDetailsSelection() {
    final selected = _selectedMetricForDetails;
    if (selected != null && metrics.contains(selected)) return selected;
    return metrics.isEmpty ? null : metrics.first;
  }

  Map<String, dynamic>? _medicalDetailsSelection() {
    final selected = _selectedMedicalRecordForDetails;
    if (selected != null) return Map<String, dynamic>.from(selected);
    return medicalRecords.isEmpty ? null : Map<String, dynamic>.from(medicalRecords.first);
  }

  Map<String, dynamic>? _diaryDetailsSelection() {
    final selected = _selectedDiaryForDetails;
    if (selected != null) return Map<String, dynamic>.from(selected);
    final day = _selectedDiaryDay;
    if (day != null) {
      for (final item in diaryItems) {
        final d = _diaryDateOf(item);
        if (d != null && _sameDateOnly(d, day)) return item;
      }
    }
    return diaryItems.isEmpty ? null : Map<String, dynamic>.from(diaryItems.first);
  }

  Map<String, dynamic>? _testingDetailsSelection() {
    final selected = _selectedTestingResultForDetails;
    if (selected != null) return Map<String, dynamic>.from(selected);
    return playerTestingResults.isEmpty ? null : Map<String, dynamic>.from(playerTestingResults.first);
  }

  Widget _buildCmrSelectionDetailsPane(_CategoryTab tab) {
    switch (tab.index) {
      case 1: // Физика
      case 51: // Нагрузка
        if (_rightEditorMode == _CmrRightEditorMode.metrics) return _buildMetricEditorRightPane();
        return _buildMetricRightDetailsPane();
      case 2: // Медиа / достижения
        if (_rightEditorMode == _CmrRightEditorMode.media) return _buildMediaEditorRightPane();
        return _buildAchievementRightDetailsPane();
      case 3:
        if (_rightEditorMode == _CmrRightEditorMode.medicalRecord) return _buildMedicalRecordEditorRightPane();
        return _buildMedicalRightDetailsPane();
      case 4:
      case 54:
        if (_rightEditorMode == _CmrRightEditorMode.coachNote) return _buildCoachNoteRightEditorPane();
        if (_rightEditorMode == _CmrRightEditorMode.playerRating) return _buildCoachRatingRightEditorPane();
        return _buildTrainingRightDetailsPane();
      case 52:
        return _buildAttendanceReportRightPane();
      case 5:
        return _buildMatchRightDetailsPane();
      case 50:
        return _buildTtdRightDetailsPane();
      case 7:
        return _buildTestingRightDetailsPane();
      case 8:
        return _buildExportRightDetailsPane();
      default:
        return _buildCmrRightPlaceholder(tab);
    }
  }

  Widget _buildCmrRightDetailsShell({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color? accent,
    List<Widget> actions = const [],
  }) {
    final c = accent ?? _AppColors.accentForIcon(icon);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: _AppColors.softFor(c), borderRadius: BorderRadius.circular(18)),
                      child: Icon(icon, color: c, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 17.2, wide: 19.2, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 11.5, wide: 12.4, color: _AppColors.textSecondary, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmrRightPlaceholder(_CategoryTab tab) {
    final accent = _cmrTabAccent(tab.index);
    return _buildCmrRightDetailsShell(
      icon: tab.icon,
      title: 'Детали раздела',
      subtitle: 'Выберите карточку в центральной части — подробности откроются здесь.',
      accent: accent,
      child: _buildEmptyState(
        icon: tab.icon,
        message: 'Правая область работает без модальных окон: список остаётся слева, выбранный объект — справа.',
      ),
    );
  }

  Widget _buildRightEditorActionBar({
    required bool saving,
    required String saveLabel,
    required Future<void> Function() onSave,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : _closeRightEditor,
            style: OutlinedButton.styleFrom(
              foregroundColor: _AppColors.textPrimary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: saving ? null : () { onSave(); },
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(saveLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricEditorRightPane() {
    final rawInitial = metrics.isNotEmpty
        ? List<String>.from(metrics)
        : _asStr(widget.player['sport_data'])
            .split(RegExp(r'[\n,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final titleControllers = <TextEditingController>[];
    final valueControllers = <TextEditingController>[];

    void addControllerPair([String raw = '']) {
      final parsed = _splitMetricLine(raw);
      titleControllers.add(TextEditingController(text: parsed['title'] ?? ''));
      valueControllers.add(TextEditingController(text: parsed['value'] ?? ''));
    }

    if (rawInitial.isEmpty) {
      if (_selectedTabIndex == 51) {
        addControllerPair('Скорость: ');
        addControllerPair('Дистанция: ');
        addControllerPair('Выносливость: ');
      } else {
        addControllerPair('Рост: ');
        addControllerPair('Вес: ');
        addControllerPair('ЧСС: ');
      }
    } else {
      for (final item in rawInitial) {
        addControllerPair(item);
      }
    }

    bool saving = false;

    return StatefulBuilder(
      builder: (context, setPaneState) {
        Future<void> saveMetrics() async {
          if (saving) return;
          final nextMetrics = <String>[];
          for (int i = 0; i < titleControllers.length; i++) {
            final line = _joinMetricLine(titleControllers[i], valueControllers[i]);
            if (line.isNotEmpty) nextMetrics.add(line);
          }

          setPaneState(() => saving = true);
          try {
            final value = nextMetrics.join('\n');
            await _savePlayerField({'sport_data': value, 'metrics': value});
            if (!mounted) return;
            setState(() {
              metrics = nextMetrics;
              widget.player['sport_data'] = value;
              widget.player['metrics'] = value;
              _selectedMetricForDetails = nextMetrics.isNotEmpty ? nextMetrics.last : null;
              _rightEditorMode = null;
            });
            _rebuildOpenSectionSheet();
            _showSnack('Метрики сохранены');
          } catch (_) {
            if (!mounted) return;
            setPaneState(() => saving = false);
            _showSnack('Не удалось сохранить метрики');
          }
        }

        Widget metricRow(int index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFEAF5EE), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.speed_rounded, color: Color(0xFF178A45), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: titleControllers[index],
                    enabled: !saving,
                    decoration: _inputDecoration('Показатель').copyWith(hintText: 'Например: Рост'),
                    style: _bodyStyle(size: 12.8, color: _AppColors.textPrimary, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: valueControllers[index],
                    enabled: !saving,
                    decoration: _inputDecoration('Значение').copyWith(hintText: '175 см'),
                    style: _bodyStyle(size: 12.8, color: _AppColors.textPrimary, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Удалить показатель',
                  visualDensity: VisualDensity.compact,
                  onPressed: saving
                      ? null
                      : () {
                          if (titleControllers.length <= 1) {
                            titleControllers[index].clear();
                            valueControllers[index].clear();
                            setPaneState(() {});
                            return;
                          }
                          final t = titleControllers.removeAt(index);
                          final v = valueControllers.removeAt(index);
                          t.dispose();
                          v.dispose();
                          setPaneState(() {});
                        },
                  icon: const Icon(Icons.delete_outline_rounded, color: _AppColors.error),
                ),
              ],
            ),
          );
        }

        return _buildCmrRightDetailsShell(
          icon: _selectedTabIndex == 51 ? Icons.monitor_heart_rounded : Icons.health_and_safety_rounded,
          title: _selectedTabIndex == 51 ? 'Добавить нагрузку' : 'Добавить физику',
          subtitle: 'Форма открыта справа — список остаётся на экране.',
          accent: _selectedTabIndex == 51 ? _AppColors.blue : _AppColors.cmrGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _matchDetailTextBlock(
                Icons.info_outline_rounded,
                'Как заполнять',
                'Добавьте название показателя и значение. Можно оставить несколько строк: рост, вес, скорость, дистанция, выносливость и любые свои метрики.',
              ),
              const SizedBox(height: 12),
              ...List.generate(titleControllers.length, metricRow),
              const SizedBox(height: 2),
              _compactActionButton(
                icon: Icons.add_rounded,
                label: 'Ещё показатель',
                compact: false,
                onTap: saving
                    ? null
                    : () {
                        addControllerPair('');
                        setPaneState(() {});
                      },
              ),
              const SizedBox(height: 14),
              _buildRightEditorActionBar(saving: saving, saveLabel: 'Сохранить', onSave: saveMetrics),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaEditorRightPane() {
    final urlController = TextEditingController();

    bool saving = false;

    return StatefulBuilder(
      builder: (context, setPaneState) {
        Future<void> saveMedia() async {
          if (saving) return;
          final url = urlController.text.trim();
          if (url.isEmpty) {
            _showSnack('Вставьте ссылку на медиа');
            return;
          }
          setPaneState(() => saving = true);
          try {
            final next = [...mediaLinks, url];
            final joined = next.join('\n');
            await _savePlayerField({'media': joined, 'media_links': joined});
            if (!mounted) return;
            setState(() {
              mediaLinks = next;
              widget.player['media'] = joined;
              widget.player['media_links'] = joined;
              _selectedMediaForDetails = url;
              _rightEditorMode = null;
            });
            _rebuildOpenSectionSheet();
            _showSnack('Медиа добавлено');
          } catch (_) {
            if (!mounted) return;
            setPaneState(() => saving = false);
            _showSnack('Не удалось добавить медиа');
          }
        }

        return _buildCmrRightDetailsShell(
          icon: Icons.add_photo_alternate_outlined,
          title: 'Добавить медиа',
          subtitle: 'Фото, видео или файл откроются в портфолио игрока.',
          accent: _AppColors.cmrGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCmrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.collections_outlined, color: _AppColors.cmrGreen, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Ссылка на материал', style: TextStyle(color: _AppColors.textPrimary, fontSize: 12.2, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      enabled: !saving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: _inputDecoration('Ссылка на фото, видео или файл'),
                      style: _bodyStyle(size: 13, color: _AppColors.textPrimary, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _matchDetailTextBlock(Icons.link_rounded, 'Подсказка', 'Можно вставить прямую ссылку на изображение, видео или документ. После сохранения материал появится слева и в правой карточке.'),
              const SizedBox(height: 14),
              _buildRightEditorActionBar(saving: saving, saveLabel: 'Добавить медиа', onSave: saveMedia),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicalRecordEditorRightPane() {
    final record = _rightEditorMedicalRecord;
    final isEdit = record != null;
    final typeController = TextEditingController(text: isEdit ? _asStr(record?['type']) : '');
    final titleController = TextEditingController(text: isEdit ? _asStr(record?['title']) : '');
    final valueController = TextEditingController(text: isEdit ? _asStr(record?['value']) : '');
    final commentController = TextEditingController(text: isEdit ? _asStr(record?['comment']) : '');
    DateTime selectedDate = DateTime.tryParse(isEdit ? _asStr(record?['date']) : '') ?? DateTime.now();
    XFile? selectedFile;
    bool isUploading = false;

    return StatefulBuilder(
      builder: (context, setPaneState) {
        Future<void> pickDate() async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _AppColors.primaryGreen)),
                child: child!,
              );
            },
          );
          if (picked != null) setPaneState(() => selectedDate = picked);
        }

        Future<void> pickFile({required bool imageOnly}) async {
          final picker = ImagePicker();
          final file = imageOnly ? await picker.pickImage(source: ImageSource.gallery) : await picker.pickMedia();
          if (file != null) setPaneState(() => selectedFile = file);
        }

        Future<void> saveRecord() async {
          if (isUploading) return;
          final type = typeController.text.trim();
          final title = titleController.text.trim();
          final value = valueController.text.trim();
          final comment = commentController.text.trim();

          if (title.isEmpty && value.isEmpty) {
            _showSnack('Заполните название или описание записи');
            return;
          }

          setPaneState(() => isUploading = true);
          try {
            final uri = Uri.parse(isEdit ? '$_apiBase/medical/update_record.php' : '$_apiBase/medical/add_record.php');
            final request = http.MultipartRequest('POST', uri);

            if (isEdit) {
              request.fields['id'] = _asStr(record?['id']);
            } else {
              request.fields['user_id'] = widget.player['user_id'].toString();
            }

            request.fields['type'] = type.isEmpty ? 'Запись' : type;
            request.fields['title'] = title;
            request.fields['value'] = value;
            request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
            request.fields['comment'] = comment;

            if (selectedFile != null) {
              request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path));
            }

            final response = await request.send();
            final responseBody = await response.stream.bytesToString();
            bool success = response.statusCode == 200;
            String? serverMessage;
            try {
              final decoded = jsonDecode(responseBody);
              if (decoded is Map) {
                success = decoded['success'] == true || decoded['status'] == 'success' || response.statusCode == 200;
                serverMessage = _asStr(decoded['message'] ?? decoded['error']);
              }
            } catch (_) {}

            if (!mounted) return;
            if (!success) {
              setPaneState(() => isUploading = false);
              _showSnack(serverMessage?.isNotEmpty == true ? serverMessage! : 'Не удалось сохранить запись');
              return;
            }

            await _loadMedicalRecords();
            if (!mounted) return;
            final editedId = isEdit ? _asStr(record?['id']) : '';
            Map<String, dynamic>? selected;
            if (medicalRecords.isNotEmpty) {
              selected = medicalRecords.firstWhere(
                (x) => editedId.isNotEmpty && _asStr(x['id']) == editedId,
                orElse: () => medicalRecords.first,
              );
            }
            setState(() {
              _selectedMedicalRecordForDetails = selected == null ? null : Map<String, dynamic>.from(selected);
              _rightEditorMode = null;
              _rightEditorMedicalRecord = null;
            });
            _rebuildOpenSectionSheet();
            _showSnack(isEdit ? 'Медицинская запись обновлена' : 'Медицинская запись добавлена');
          } catch (e) {
            debugPrint('Error saving medical record: $e');
            if (!mounted) return;
            setPaneState(() => isUploading = false);
            _showSnack('Ошибка сохранения: $e');
          }
        }

        return _buildCmrRightDetailsShell(
          icon: Icons.medical_information_rounded,
          title: isEdit ? 'Редактировать запись' : 'Добавить запись',
          subtitle: 'Медкарта открывается в правой рабочей панели.',
          accent: _AppColors.cmrGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMedicalEditorSection(
                title: 'Тип записи',
                icon: Icons.category_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMedicalTypeChip('Осмотр', typeController, setPaneState),
                        _buildMedicalTypeChip('Травма', typeController, setPaneState),
                        _buildMedicalTypeChip('Вакцинация', typeController, setPaneState),
                        _buildMedicalTypeChip('Справка', typeController, setPaneState),
                        _buildMedicalTypeChip('Рекомендация', typeController, setPaneState),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMedicalEditorInput(controller: typeController, hint: 'Можно указать свой тип', icon: Icons.edit_note_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildMedicalEditorSection(
                title: 'Основная информация',
                icon: Icons.medical_information_rounded,
                child: Column(
                  children: [
                    _buildMedicalEditorInput(controller: titleController, hint: 'Название: медосмотр, справка, травма...', icon: Icons.title_rounded),
                    const SizedBox(height: 10),
                    _buildMedicalEditorInput(controller: valueController, hint: 'Описание / значение', icon: Icons.notes_rounded, minLines: 3, maxLines: 5),
                    const SizedBox(height: 10),
                    _buildMedicalEditorInput(controller: commentController, hint: 'Комментарий тренера или врача', icon: Icons.chat_bubble_outline_rounded, minLines: 2, maxLines: 4),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildMedicalEditorSection(
                title: 'Дата и вложения',
                icon: Icons.event_available_rounded,
                child: Column(
                  children: [
                    _buildMedicalDateCard(date: selectedDate, onTap: pickDate),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMedicalAttachButton(icon: Icons.image_rounded, title: 'Фото', subtitle: 'Из галереи', onTap: () => pickFile(imageOnly: true))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMedicalAttachButton(icon: Icons.attach_file_rounded, title: 'Файл', subtitle: 'PDF / DOC', onTap: () => pickFile(imageOnly: false))),
                      ],
                    ),
                    if (selectedFile != null) ...[
                      const SizedBox(height: 10),
                      _buildSelectedMedicalFileCard(fileName: selectedFile!.name, onClear: () => setPaneState(() => selectedFile = null)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildRightEditorActionBar(saving: isUploading, saveLabel: isEdit ? 'Сохранить изменения' : 'Добавить запись', onSave: saveRecord),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoachRatingRightEditorPane() {
    final ev = selectedEvent;
    final eventId = ev == null ? 0 : _trainingRowEventId(ev);
    final date = ev == null ? '' : _anyDateStr(ev);
    final trainingTitle = ev == null ? '' : _firstNotEmpty([ev['title'], ev['event_title'], ev['name']]).trim();
    final title = trainingTitle.isEmpty ? 'Тренировка' : trainingTitle;

    if (ev == null || eventId <= 0) {
      return _buildCmrRightDetailsShell(
        icon: Icons.workspace_premium_rounded,
        title: 'Оценка игрока',
        subtitle: 'Выберите тренировку в календаре или списке.',
        child: _buildEmptyState(icon: Icons.event_busy_rounded, message: 'Сначала выберите тренировку, чтобы поставить оценку игроку.'),
      );
    }

    int selectedRating = _normalizeRatingValue(
          _firstRatingValue(selectedEventPlayerInfo, _coachRatingKeys) ??
              _firstRatingValue(ev, _coachRatingKeys),
        ) ??
        0;
    bool saving = false;

    return StatefulBuilder(
      builder: (context, setPaneState) {
        Future<void> saveRating() async {
          if (saving) return;
          if (selectedRating < 1) {
            _showSnack('Выберите оценку от 1 до 5');
            return;
          }

          final playerId = await _resolvePlayerId();
          if (playerId <= 0) {
            _showSnack('Не удалось определить player_id');
            return;
          }

          setPaneState(() => saving = true);
          try {
            await _saveCoachRatingForEvent(eventId: eventId, playerId: playerId, rating: selectedRating);
            if (!mounted) return;
            setState(() {
              _patchCoachRatingLocally(eventId: eventId, rating: selectedRating);
              _rightEditorMode = null;
            });
            await _loadPlayerInfoForEvent(eventId);
            await _loadAttendanceLog(force: true);
            await _loadPlayerTrainingHistory(force: true);
            await _loadTeamCalendar(force: true);
            if (!mounted) return;
            setState(() => _patchCoachRatingLocally(eventId: eventId, rating: selectedRating));
            _rebuildOpenSectionSheet();
            _showSnack('Оценка сохранена');
          } catch (e) {
            if (!mounted) return;
            setPaneState(() => saving = false);
            _showSnack(e.toString());
          }
        }

        return _buildCmrRightDetailsShell(
          icon: Icons.workspace_premium_rounded,
          title: 'Оценка игрока',
          subtitle: date.isEmpty ? title : '$title • $date',
          accent: _AppColors.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _matchDetailTextBlock(
                Icons.info_outline_rounded,
                'Оценка тренера',
                'Поставьте оценку выбранному игроку за конкретную тренировку. Она появится в карточке тренировки и маленьким бейджем в календаре.',
              ),
              const SizedBox(height: 12),
              _buildCmrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.star_rounded, color: _AppColors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Оценка от 1 до 5', style: TextStyle(color: _AppColors.textPrimary, fontSize: 12.2, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 12),
                    _buildRatingPicker(
                      value: selectedRating,
                      enabled: !saving,
                      onChanged: (v) => setPaneState(() => selectedRating = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildRightEditorActionBar(saving: saving, saveLabel: 'Сохранить оценку', onSave: saveRating),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoachNoteRightEditorPane() {
    final ev = selectedEvent;
    final eventId = ev == null ? 0 : _asInt(ev['event_id'] ?? ev['id']);
    final date = ev == null ? '' : _anyDateStr(ev);
    final trainingTitle = ev == null ? '' : _firstNotEmpty([ev['title'], ev['event_title'], ev['name']]).trim();
    final title = trainingTitle.isEmpty ? 'Тренировка' : trainingTitle;
    final currentNote = _asStr(selectedEventPlayerInfo?['coach_note'] ?? ev?['coach_note']).trim();
    final noteController = TextEditingController(text: currentNote);

    if (ev == null || eventId <= 0) {
      return _buildCmrRightDetailsShell(
        icon: Icons.star_rounded,
        title: 'Оценка тренера',
        subtitle: 'Выберите тренировку слева.',
        child: _buildEmptyState(icon: Icons.event_busy_rounded, message: 'Сначала выберите тренировку или дату, чтобы добавить заметку тренера.'),
      );
    }

    bool saving = false;

    return StatefulBuilder(
      builder: (context, setPaneState) {
        Future<void> saveNote() async {
          if (saving) return;
          final playerId = await _resolvePlayerId();
          if (playerId <= 0) {
            _showSnack('Не удалось определить player_id');
            return;
          }
          setPaneState(() => saving = true);
          try {
            await _saveCoachNoteForEvent(eventId: eventId, playerId: playerId, note: noteController.text);
            if (!mounted) return;
            setState(() {
              selectedEventPlayerInfo = {
                ...(selectedEventPlayerInfo ?? {}),
                'coach_note': noteController.text.trim(),
              };
              _rightEditorMode = null;
            });
            await _loadPlayerInfoForEvent(eventId);
            _rebuildOpenSectionSheet();
            _showSnack('Заметка сохранена');
          } catch (e) {
            if (!mounted) return;
            setPaneState(() => saving = false);
            _showSnack(e.toString());
          }
        }

        return _buildCmrRightDetailsShell(
          icon: Icons.workspace_premium_rounded,
          title: 'Заметка тренера',
          subtitle: date.isEmpty ? title : '$title • $date',
          accent: _AppColors.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _matchDetailTextBlock(Icons.star_outline_rounded, 'Оценка тренера', 'Заметка сохраняется для выбранной тренировки и не смешивается с самооценкой игрока.'),
              const SizedBox(height: 12),
              _buildCmrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.sticky_note_2_rounded, color: _AppColors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Комментарий к тренировке', style: TextStyle(color: _AppColors.textPrimary, fontSize: 12.2, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      enabled: !saving,
                      minLines: 6,
                      maxLines: 12,
                      decoration: _inputDecoration('Что улучшить, на что обратить внимание, домашнее задание…'),
                      style: _bodyStyle(size: 13, color: _AppColors.textPrimary, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildRightEditorActionBar(saving: saving, saveLabel: 'Сохранить заметку', onSave: saveNote),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricRightDetailsPane() {
    final metric = _metricDetailsSelection();
    if (metric == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.query_stats_rounded,
        title: 'Метрика игрока',
        subtitle: 'Выберите показатель в списке слева.',
        child: _buildEmptyState(icon: Icons.query_stats_outlined, message: 'Метрики пока не заполнены.'),
        actions: [_buildCmrEditButton(icon: Icons.add_chart_rounded, label: 'Добавить', onTap: _showEditMetricsDialog)],
      );
    }

    final parsed = _splitMetricLine(metric);
    final title = (parsed['title'] ?? '').trim().isEmpty ? 'Показатель' : (parsed['title'] ?? '').trim();
    final value = (parsed['value'] ?? '').trim().isEmpty ? 'Не указано' : (parsed['value'] ?? '').trim();
    final accent = _metricAccent(title);
    final group = _metricGroup(title);

    return _buildCmrRightDetailsShell(
      icon: _metricIcon(title),
      title: title,
      subtitle: 'Подробная карточка спортивного показателя',
      accent: accent,
      actions: [_buildCmrEditButton(icon: Icons.edit_rounded, label: 'Редактировать', onTap: _showEditMetricsDialog)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCmrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: _cmrTitleText(context, mobile: 26, wide: 30, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _matchDetailPill(_metricGroupIcon(group), 'Группа', group, color: accent),
                  _matchDetailPill(Icons.verified_user_outlined, 'Профиль', '${_profileReadinessPercent()}%', color: _AppColors.cmrGreen),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _matchDetailTextBlock(Icons.info_outline_rounded, 'Подсказка', 'Нажимайте на показатели слева, чтобы быстро сравнивать данные без открытия отдельного окна.'),
        ],
      ),
    );
  }

  Widget _buildAchievementRightDetailsPane() {
    final achievementsText = _asStr(widget.player['achievements']).trim();
    final media = _selectedMediaForDetails ?? (mediaLinks.isNotEmpty ? mediaLinks.first : null);
    final title = media == null ? 'Достижения игрока' : 'Медиа игрока';
    final subtitle = media == null ? 'Награды и сильные стороны' : 'Выбранный материал портфолио';

    return _buildCmrRightDetailsShell(
      icon: media == null ? Icons.military_tech_rounded : Icons.collections_rounded,
      title: title,
      subtitle: subtitle,
      accent: media == null ? _AppColors.orange : _AppColors.cmrGreen,
      actions: [
        _buildCmrEditButton(icon: Icons.emoji_events_rounded, label: 'Достижение', onTap: _showEditAchievementsDialog),
        _buildCmrActionChip(icon: Icons.add_photo_alternate_outlined, label: 'Медиа', onTap: _showAddMediaDialog, compact: true),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (media != null) ...[
            _buildSelectedMediaPreview(media),
            const SizedBox(height: 12),
          ],
          _buildCmrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.workspace_premium_rounded, color: _AppColors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Ключевые достижения', style: TextStyle(color: _AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 10),
                Text(
                  achievementsText.isEmpty ? 'Достижения пока не заполнены. Можно добавить турниры, награды, MVP и важные игровые события.' : achievementsText,
                  style: _bodyStyle(size: 13, color: _AppColors.textSecondary, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedMediaPreview(String url) {
    final norm = _normalizeImage(url) ?? url;
    final lower = norm.toLowerCase();
    final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
    final isVideo = lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v');
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(24),
        image: isImage ? DecorationImage(image: NetworkImage(norm), fit: BoxFit.cover) : null,
      ),
      child: Stack(
        children: [
          if (!isImage) Center(child: Icon(isVideo ? Icons.play_circle_fill_rounded : Icons.attach_file_rounded, color: _AppColors.cmrGreen, size: 54)),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                _buildTrainingMetaPill(isVideo ? Icons.play_circle_outline_rounded : Icons.collections_outlined, isVideo ? 'Видео' : isImage ? 'Фото' : 'Файл', _AppColors.cmrGreen),
                const Spacer(),
                _compactActionButton(icon: Icons.open_in_new_rounded, label: 'Открыть', onTap: () => launchUrl(Uri.parse(norm), mode: LaunchMode.externalApplication), compact: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalRightDetailsPane() {
    final record = _medicalDetailsSelection();
    if (record == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.medical_information_rounded,
        title: 'Медкарта',
        subtitle: 'Выберите запись в центральной части.',
        child: _buildEmptyState(icon: Icons.medical_services_outlined, message: 'Медицинских записей пока нет.'),
        actions: [_buildCmrEditButton(icon: Icons.add_rounded, label: 'Добавить', onTap: _showAddMedicalRecordDialog)],
      );
    }

    final type = _asStr(record['type']).isEmpty ? 'Запись' : _asStr(record['type']);
    final title = _asStr(record['title']).isEmpty ? 'Без названия' : _asStr(record['title']);
    final value = _asStr(record['value']);
    final comment = _asStr(record['comment']);
    final date = _asStr(record['date']).isEmpty ? 'Дата не указана' : _asStr(record['date']);
    final fileUrl = _asStr(record['file_url']);
    final accent = _medicalAccent('$type $title $value');

    return _buildCmrRightDetailsShell(
      icon: _medicalIcon('$type $title $value'),
      title: title,
      subtitle: type,
      accent: accent,
      actions: [
        _buildCmrEditButton(icon: Icons.add_rounded, label: 'Добавить', onTap: _showAddMedicalRecordDialog),
        _buildCmrEditButton(icon: Icons.edit_rounded, label: 'Редактировать', onTap: () => _showEditMedicalRecordDialog(record)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _matchDetailPill(Icons.event_rounded, 'Дата', date, color: accent),
          _matchDetailPill(Icons.medical_information_outlined, 'Тип', type, color: accent),
          _matchDetailPill(Icons.attach_file_rounded, 'Файл', fileUrl.isEmpty ? 'нет' : 'есть', color: accent),
        ]),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 12),
          _matchDetailTextBlock(Icons.description_outlined, 'Значение', value),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _matchDetailTextBlock(Icons.chat_bubble_outline_rounded, 'Комментарий', comment),
        ],
        if (fileUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          _compactActionButton(icon: Icons.open_in_new_rounded, label: 'Открыть файл', onTap: () => launchUrl(Uri.parse(_normalizeImage(fileUrl) ?? fileUrl), mode: LaunchMode.externalApplication), compact: false),
        ],
      ]),
    );
  }

  Widget _buildAttendanceReportRightPane() {
    final item = _trainingDetailsSelection();
    final d = item == null ? null : _parseEventDate(item);
    final titleDate = d == null ? 'выбранную дату' : DateFormat('dd.MM.yyyy').format(d);
    final type = item == null ? 'Посещаемость' : _attendanceEventTypeLabel(item);
    final stage = item == null ? _attendanceStageLabel(const <String, dynamic>{}) : _attendanceStageLabel(item);

    return _buildCmrRightDetailsShell(
      icon: Icons.event_available_rounded,
      title: 'Отчёт за $titleDate',
      subtitle: '$type • $stage',
      accent: _AppColors.cmrGreen,
      child: _buildAttendanceReportContent(item),
    );
  }


  Color _trainingRatingAccent(dynamic rating) {
    final value = _normalizeRatingValue(rating);
    if (value == null) return _AppColors.textTertiary;
    if (value <= 2) return _AppColors.error;
    if (value == 3) return _AppColors.orange;
    return _AppColors.cmrGreen;
  }

  String _trainingRatingValueText(dynamic rating) {
    final value = _normalizeRatingValue(rating);
    return value == null ? '—' : '$value/5';
  }

  String _trainingRatingHint(dynamic rating, {required bool coach}) {
    final value = _normalizeRatingValue(rating);
    if (value == null) return coach ? 'нет оценки тренера' : 'нет самооценки';
    if (value <= 2) return 'требует внимания';
    if (value == 3) return 'средний уровень';
    if (value == 4) return 'хороший уровень';
    return 'отличный уровень';
  }

  Widget _buildRatingPicker({
    required int value,
    required ValueChanged<int> onChanged,
    bool enabled = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final active = value == rating;
        final accent = _trainingRatingAccent(rating);
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => onChanged(rating) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 54,
              height: 48,
              decoration: BoxDecoration(
                color: active ? accent : _AppColors.softFor(accent),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: active ? Colors.white : accent),
                  const SizedBox(width: 3),
                  Text(
                    '$rating',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12.6,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTrainingScoreTile({
    required String title,
    required dynamic rating,
    required IconData icon,
    required bool coach,
  }) {
    final accent = _trainingRatingAccent(rating);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrSubtitleText(context, mobile: 11.2, wide: 11.6, color: _AppColors.textSecondary, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            _trainingRatingValueText(rating),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 20.6,
              height: 0.95,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _trainingRatingHint(rating, coach: coach),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cmrSubtitleText(context, mobile: 10.7, wide: 11.2, color: _AppColors.textSecondary, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingScoreGrid({required dynamic playerRating, required dynamic coachRating}) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 390;
        final player = _buildTrainingScoreTile(
          title: 'Самооценка игрока',
          rating: playerRating,
          icon: Icons.star_rounded,
          coach: false,
        );
        final coach = _buildTrainingScoreTile(
          title: 'Оценка тренера',
          rating: coachRating,
          icon: Icons.workspace_premium_rounded,
          coach: true,
        );
        if (!wide) {
          return Column(children: [player, const SizedBox(height: 9), coach]);
        }
        return Row(
          children: [
            Expanded(child: player),
            const SizedBox(width: 10),
            Expanded(child: coach),
          ],
        );
      },
    );
  }

  Widget _buildTrainingProfessionalNote({
    required IconData icon,
    required String title,
    required String text,
    required Color accent,
    bool subtleWhenEmpty = false,
  }) {
    final value = text.trim();
    final empty = value.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: empty || subtleWhenEmpty ? _AppColors.cmrSoftPanel : _AppColors.softFor(accent),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: empty ? _AppColors.textTertiary : accent, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrSubtitleText(context, mobile: 11.6, wide: 12.0, color: empty ? _AppColors.textSecondary : accent, weight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  empty ? 'Пока не заполнено' : value,
                  style: _cmrBodyText(context, mobile: 12.2, wide: 12.8, color: empty ? _AppColors.textTertiary : _AppColors.textPrimary, weight: FontWeight.w700, height: 1.38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingTopReportCard({
    required String title,
    required String date,
    required String typeLabel,
    required ({String text, Color color, IconData icon}) meta,
    required String reason,
  }) {
    final subtitle = [if (date.isNotEmpty) date, if (typeLabel.isNotEmpty) typeLabel].join(' • ');
    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _AppColors.softFor(meta.color), borderRadius: BorderRadius.circular(18)),
                child: Icon(meta.icon, color: meta.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Тренировка' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrTitleText(context, mobile: 17, wide: 18.2, color: _AppColors.textPrimary, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle.isEmpty ? 'Дата и тип не указаны' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cmrSubtitleText(context, mobile: 11.8, wide: 12.4, color: _AppColors.textSecondary, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _matchDetailPill(meta.icon, 'Статус', meta.text, color: meta.color),
              if (typeLabel.isNotEmpty) _matchDetailPill(Icons.category_rounded, 'Тип', typeLabel, color: _AppColors.cmrGreen),
              if (reason.isNotEmpty) _matchDetailPill(Icons.info_outline_rounded, 'Причина', reason, color: _AppColors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingRightDetailsPane() {
    final item = _trainingDetailsSelection();
    if (item == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.fitness_center_rounded,
        title: 'Детали тренировки',
        subtitle: 'Выберите дату или карточку тренировки.',
        child: _buildEmptyState(icon: Icons.event_busy_rounded, message: 'Тренировок пока нет.'),
        actions: [_buildCmrEditButton(icon: Icons.add_task_rounded, label: 'Назначить', onTap: _assignTraining)],
      );
    }
    final date = _anyDateStr(item);
    final eventId = _trainingRowEventId(item);
    return _buildCmrRightDetailsShell(
      icon: Icons.fitness_center_rounded,
      title: date.isEmpty ? 'Отчёт тренировки' : 'Отчёт за $date',
      subtitle: 'Посещаемость, самооценка игрока, оценка тренера и заметки',
      accent: _AppColors.cmrGreen,
      actions: [
        if (eventId > 0)
          _buildCmrEditButton(
            icon: Icons.star_rounded,
            label: 'Оценка',
            onTap: () async {
              await _selectTrainingForDetails(item, loadInfo: true);
              if (mounted) await _openCoachRatingSheet();
            },
          ),
        if (eventId > 0)
          _buildCmrEditButton(
            icon: Icons.edit_note_rounded,
            label: 'Заметка',
            onTap: () async {
              await _selectTrainingForDetails(item, loadInfo: true);
              if (mounted) await _openCoachNoteSheet();
            },
          ),
        _buildCmrEditButton(icon: Icons.add_task_rounded, label: 'Назначить', onTap: _assignTraining),
      ],
      child: _buildTrainingInlineDetailsCard(item),
    );
  }

  Widget _buildTrainingInlineDetailsCard(Map<String, dynamic> raw) {
    final e = _enrichTrainingRecord(raw);
    final id = _trainingRowEventId(e);
    final title = _firstNotEmpty([e['title'], e['event_title'], e['name']]).trim();
    final date = _anyDateStr(e);
    final type = _firstNotEmpty([e['type'], e['training_type'], e['category']]).trim();
    final typeLabel = _ruTrainingType(type);
    final description = _firstNotEmpty([e['description'], e['body'], e['details']]).trim();
    final status = _attendanceStatusOf(e);
    final lateMin = _asInt(e['late_minutes'] ?? e['late']);
    final reason = _firstNotEmpty([e['reason'], e['absence_reason']]).trim();
    final meta = _statusMeta(status, lateMin);
    final playerRating = _firstRatingValue(e, _playerRatingKeys);
    final coachRating = _firstRatingValue(e, _coachRatingKeys);
    final coachComment = _firstNotEmpty([e['coach_comment'], e['trainer_comment'], e['comment']]).trim();
    final note = _firstNotEmpty([e['coach_note'], e['trainer_note'], e['note_coach'], e['note'], e['attendance_note']]).trim();
    final playerNote = _firstNotEmpty([e['player_note'], e['self_note'], e['diary_note'], e['player_comment'], e['self_comment']]).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrainingTopReportCard(
          title: title,
          date: date,
          typeLabel: typeLabel,
          meta: meta,
          reason: reason,
        ),
        _buildTrainingScoreGrid(playerRating: playerRating, coachRating: coachRating),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildTrainingProfessionalNote(
            icon: Icons.description_outlined,
            title: 'Описание тренировки',
            text: description,
            accent: _AppColors.cmrGreen,
          ),
        ],
        const SizedBox(height: 10),
        _buildTrainingProfessionalNote(
          icon: Icons.menu_book_rounded,
          title: 'Заметка игрока',
          text: playerNote,
          accent: _AppColors.cmrGreen,
          subtleWhenEmpty: playerNote.isEmpty,
        ),
        if (coachComment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildTrainingProfessionalNote(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Комментарий тренера',
            text: coachComment,
            accent: _AppColors.blue,
          ),
        ],
        const SizedBox(height: 10),
        _buildTrainingProfessionalNote(
          icon: Icons.sticky_note_2_outlined,
          title: 'Заметка тренера',
          text: note,
          accent: _AppColors.orange,
          subtleWhenEmpty: note.isEmpty,
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _compactActionButton(icon: Icons.visibility_rounded, label: 'В списке', onTap: id <= 0 ? null : () => _selectTrainingForDetails(e, loadInfo: true), compact: false),
          _compactActionButton(icon: Icons.star_rounded, label: 'Оценка игрока', onTap: id <= 0 ? null : () async { await _selectTrainingForDetails(e, loadInfo: true); if (mounted) await _openCoachRatingSheet(); }, compact: false),
          _compactActionButton(icon: Icons.edit_note_rounded, label: 'Заметка тренера', onTap: id <= 0 ? null : () async { await _selectTrainingForDetails(e, loadInfo: true); if (mounted) await _openCoachNoteSheet(); }, compact: false),
        ]),
      ],
    );
  }

  bool _hasMatchTtd(Map<String, dynamic> match) {
    final direct = _firstNotEmpty([
      match['ttd_text'],
      match['ttd'],
      match['ttd_status'],
      match['ttd_report'],
      match['report_ttd'],
    ]).trim();
    if (direct.isNotEmpty && direct != '0' && direct.toLowerCase() != 'false') return true;

    final flag = _firstNotEmpty([match['has_ttd'], match['ttd_exists'], match['is_ttd_ready']]).toLowerCase();
    if (flag == '1' || flag == 'true' || flag == 'yes' || flag == 'есть') return true;

    return _isSelectedMatchLoaded(match);
  }

  bool _isSelectedMatchLoaded(Map<String, dynamic> match) {
    if (selectedTtdMatch == null) return false;
    final matchId = _asInt(match['match_id'] ?? match['id']);
    final selectedId = _asInt(selectedTtdMatch!['match_id'] ?? selectedTtdMatch!['id']);
    if (matchId <= 0 || matchId != selectedId) return false;
    return playerTtdSummary.isNotEmpty ||
        playerTtdMainRows.isNotEmpty ||
        playerTtdPassRows.isNotEmpty ||
        playerTtdGoalkeeperRows.isNotEmpty;
  }

  bool _matchHasVideo(Map<String, dynamic> match) => _matchVideoUrl(match).isNotEmpty;

  String _matchVideoUrl(Map<String, dynamic> match) {
    return _firstNotEmpty([
      match['video_url'],
      match['video'],
      match['video_link'],
      match['videoUrl'],
      match['match_video'],
    ]).trim();
  }

  String _matchCoachComment(Map<String, dynamic> match) {
    return _firstNotEmpty([
      match['notes'],
      match['coach_comment'],
      match['trainer_comment'],
      match['comment'],
      match['ttd_comment'],
    ]).trim();
  }

  Color _ttdAccentForMatches(List<Map<String, dynamic>> rows) {
    var out = _AppColors.cmrGreen;
    for (final m in rows) {
      final rating = _matchTtdRating(m);
      if (rating != null && rating < 6) return _AppColors.error;
      if (rating != null && rating < 7) out = _AppColors.orange;
      final result = _matchResultColor(m);
      if (result == _AppColors.error) return _AppColors.error;
      if (result == _AppColors.orange && out != _AppColors.error) out = _AppColors.orange;
    }
    return out;
  }

  Color _matchResultColor(Map<String, dynamic> match) {
    final our = _asInt(match['our_score']);
    final opp = _asInt(match['opponent_score']);
    final rawOur = _asStr(match['our_score']).trim();
    final rawOpp = _asStr(match['opponent_score']).trim();
    if (rawOur.isEmpty && rawOpp.isEmpty) return _AppColors.cmrGreen;
    if (our > opp) return _AppColors.cmrGreen;
    if (our == opp) return _AppColors.orange;
    return _AppColors.error;
  }

  String _monthShortRu(String formattedDate) {
    final parts = formattedDate.split('.');
    if (parts.length < 2) return '';
    const months = ['', 'ЯНВ', 'ФЕВ', 'МАР', 'АПР', 'МАЙ', 'ИЮН', 'ИЮЛ', 'АВГ', 'СЕН', 'ОКТ', 'НОЯ', 'ДЕК'];
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return '';
    return months[m];
  }

  double? _matchTtdRating(Map<String, dynamic> match) {
    final raw = _firstNotEmpty([
      match['ttd_rating'],
      match['ttd_score'],
      match['ttd_mark'],
      match['player_ttd_rating'],
      match['player_ttd_score'],
      match['coach_ttd_rating'],
      match['rating_ttd'],
    ]).trim();
    final direct = _firstDoubleFromString(raw);
    if (direct != null) return direct > 10 ? direct / 10 : direct;

    if (_isSelectedMatchLoaded(match)) {
      final fromSummary = _firstDoubleFromString(_findTtdValue(const ['rating', 'оценка', 'score', 'mark', 'effect_percent', 'эффективность']));
      if (fromSummary != null) return fromSummary > 10 ? fromSummary / 10 : fromSummary;
    }
    return null;
  }

  String _matchTtdRatingText(Map<String, dynamic> match) {
    final rating = _matchTtdRating(match);
    if (rating == null) return '';
    final fixed = rating.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  Color _ttdRatingColor(String value) {
    final n = _firstDoubleFromString(value);
    if (n == null) return _textTertiary;
    if (n < 6) return _AppColors.error;
    if (n < 7) return _AppColors.orange;
    return _AppColors.cmrGreen;
  }

  String _findTtdValue(List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeTtdSearch).where((e) => e.isNotEmpty).toList();
    bool fits(String key) {
      final k = _normalizeTtdSearch(key);
      if (k.isEmpty) return false;
      for (final a in normalizedAliases) {
        if (k == a || k.contains(a) || a.contains(k)) return true;
      }
      return false;
    }

    for (final e in playerTtdSummary.entries) {
      final label = _ttdLabel(e.key);
      if (fits(e.key) || fits(label)) {
        final value = _asStr(e.value).trim();
        if (value.isNotEmpty) return value;
      }
    }

    final rows = [...playerTtdMainRows, ...playerTtdPassRows, ...playerTtdGoalkeeperRows];
    for (final row in rows) {
      final title = _firstNotEmpty([row['metric'], row['title'], row['name'], row['label']]).trim();
      if (title.isNotEmpty && (fits(title) || fits(_ttdLabel(title)))) {
        final value = _firstNotEmpty([row['value'], row['count'], row['result'], row['total']]).trim();
        if (value.isNotEmpty) return value;
      }
      for (final e in row.entries) {
        if (fits(e.key) || fits(_ttdLabel(e.key))) {
          final value = _asStr(e.value).trim();
          if (value.isNotEmpty) return value;
        }
      }
    }
    return '';
  }

  String _normalizeTtdSearch(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  double? _firstDoubleFromString(String raw) {
    final s = raw.replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  double? _ttdPercentFromValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = _parseSuccessFail(trimmed);
    if (parsed != null && parsed[2] > 0) return parsed[0] / parsed[2] * 100;
    final n = _firstDoubleFromString(trimmed);
    if (n == null) return null;
    return n;
  }

  String _derivePassAccuracy() {
    final accurate = _firstDoubleFromString(_findTtdValue(const ['accurate_passes', 'successful_passes', 'точные передачи']));
    final total = _firstDoubleFromString(_findTtdValue(const ['passes_total', 'total_passes', 'передачи всего', 'передачи']));
    if (accurate == null || total == null || total <= 0) return '';
    return '${(accurate / total * 100).round()}%';
  }

  Color _ttdIndicatorColor(String value, {required bool lowerBetter, required double good, required double warn}) {
    final n = lowerBetter ? _firstDoubleFromString(value) : _ttdPercentFromValue(value);
    if (n == null) return _textTertiary;
    if (lowerBetter) {
      if (n <= good) return _AppColors.cmrGreen;
      if (n <= warn) return _AppColors.orange;
      return _AppColors.error;
    }
    if (n >= good) return _AppColors.cmrGreen;
    if (n >= warn) return _AppColors.orange;
    return _AppColors.error;
  }

  String _ttdIndicatorCaption(String value, {required bool lowerBetter, required double good, required double warn}) {
    final n = lowerBetter ? _firstDoubleFromString(value) : _ttdPercentFromValue(value);
    if (n == null) return 'Нет данных';
    if (lowerBetter) {
      if (n <= good) return 'Хорошо';
      if (n <= warn) return 'Средне';
      return 'Много';
    }
    if (n >= good) return 'Хорошо';
    if (n >= warn) return 'Средне';
    return 'Нужно улучшить';
  }

  List<Map<String, String>> _ttdProblems(Map<String, dynamic> match) {
    final out = <Map<String, String>>[];

    final losses = _firstDoubleFromString(_findTtdValue(const ['losses', 'ball_losses', 'turnovers', 'потери', 'потери мяча']));
    if (losses != null && losses > 6) {
      out.add({'title': 'Потери мяча: ${losses.toStringAsFixed(0)}', 'text': 'Выше нормы для позиции игрока'});
    }

    final duels = _ttdPercentFromValue(_findTtdValue(const ['duels', 'duels_won', 'единоборства', 'выигранные дуэли']));
    if (duels != null && duels < 50) {
      out.add({'title': 'Единоборства: ${duels.toStringAsFixed(0)}%', 'text': 'Низкий процент выигранных дуэлей'});
    }

    final passes = _ttdPercentFromValue(_findTtdValue(const ['pass_accuracy', 'passes_accuracy', 'passing_accuracy', 'точность передач', 'точные передачи']));
    if (passes != null && passes < 60) {
      out.add({'title': 'Точность передач: ${passes.toStringAsFixed(0)}%', 'text': 'Нужно улучшить игру в короткий пас'});
    }

    final shots = _ttdPercentFromValue(_findTtdValue(const ['shots', 'shots_on_target', 'удары', 'удары в створ']));
    if (shots != null && shots < 35) {
      out.add({'title': 'Удары в створ: ${shots.toStringAsFixed(0)}%', 'text': 'Нужно больше точности при завершении атак'});
    }

    if (out.length > 3) return out.take(3).toList();
    return out;
  }

  String _ttdRecommendationText(Map<String, dynamic> match) {
    final problems = _ttdProblems(match);
    if (problems.isEmpty) {
      return 'Сохранить текущую нагрузку и закрепить сильные действия в игровых упражнениях.';
    }
    final titles = problems.map((e) => _asStr(e['title']).toLowerCase()).join(' ');
    if (titles.contains('потери')) {
      return 'Сделать акцент на первом касании, игре корпусом и решениях под давлением.';
    }
    if (titles.contains('единоборства')) {
      return 'Добавить упражнения на выбор позиции, борьбу один в один и агрессивность в отборе.';
    }
    if (titles.contains('передач')) {
      return 'На следующей тренировке добавить короткий пас, открывание под передачу и контроль темпа.';
    }
    if (titles.contains('удары')) {
      return 'Отработать завершение атак после приёма мяча и удары из разных зон.';
    }
    return 'Выбрать 1–2 проблемных действия и закрепить их в индивидуальном плане игрока.';
  }

  Widget _buildTtdRightDetailsPane() {
    final match = _matchDetailsSelection();
    if (match == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.calendar_month_rounded,
        title: 'Отчёт по ТТД',
        subtitle: 'Выберите дату или матч в календаре.',
        accent: _AppColors.cmrGreen,
        child: _buildEmptyState(icon: Icons.analytics_outlined, message: 'Матчи с ТТД пока не найдены.'),
      );
    }

    final date = _formatMatchDate(_asStr(match['match_date'] ?? match['date'] ?? match['start_at']));
    final stage = _firstNotEmpty([widget.player['stage'], widget.player['age_group'], widget.player['team_stage'], widget.player['category_code']]).trim();

    return _buildCmrRightDetailsShell(
      icon: Icons.calendar_month_rounded,
      title: date.isEmpty ? 'Отчёт по ТТД' : 'Отчёт по ТТД за $date',
      subtitle: ['Матч', if (stage.isNotEmpty) stage].join(' • '),
      accent: _AppColors.cmrGreen,
      child: _buildTtdReportContent(match),
    );
  }

  Widget _buildTtdReportContent(Map<String, dynamic> match) {
    final matchId = _asInt(match['match_id'] ?? match['id']);
    final opponent = _asStr(match['opponent']).trim().isEmpty ? 'Соперник не указан' : _asStr(match['opponent']).trim();
    final tournament = _asStr(match['competition_name'] ?? match['tournament'] ?? match['type']).trim();
    final score = _matchScore(match).trim().isEmpty ? '—' : _matchScore(match).trim();
    final videoUrl = _matchVideoUrl(match);
    final hasTtd = _hasMatchTtd(match) || _isSelectedMatchLoaded(match);
    final ratingText = _matchTtdRatingText(match);
    final notes = _matchCoachComment(match);
    final isOpening = _openingPlayerMatchId == matchId && matchId > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTtdReportMatchCard(
          opponent: opponent,
          tournament: tournament,
          score: score,
          hasTtd: hasTtd,
          hasVideo: videoUrl.isNotEmpty,
          ratingText: ratingText,
          hasComment: notes.isNotEmpty,
          resultColor: _matchResultColor(match),
        ),
        const SizedBox(height: 16),
        Text('Ключевые показатели', style: _titleStyle(size: 14.2, color: _textPrimary)),
        const SizedBox(height: 9),
        _buildTtdKeyIndicatorsGrid(match),
        const SizedBox(height: 16),
        Text('Проблемные зоны', style: _titleStyle(size: 14.2, color: _textPrimary)),
        const SizedBox(height: 9),
        _buildTtdProblemZones(match),
        const SizedBox(height: 14),
        _buildTtdRecommendation(match),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _compactActionButton(
              icon: isOpening ? Icons.hourglass_top_rounded : Icons.analytics_outlined,
              label: isOpening ? 'Открываю...' : 'Показать ТТД',
              onTap: matchId <= 0 || isOpening ? null : () => _selectMatchForDetails(match, loadTtd: true),
              compact: false,
            ),
            _compactActionButton(
              icon: Icons.play_circle_outline_rounded,
              label: 'Видео матча',
              onTap: videoUrl.isEmpty ? null : () => launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication),
              compact: false,
            ),
            _compactActionButton(
              icon: Icons.edit_rounded,
              label: 'Редактировать',
              onTap: () => _showEditMatchDialog(match),
              compact: false,
            ),
            _compactActionButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Экспорт PDF',
              onTap: _exportPlayerPdf,
              compact: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTtdReportMatchCard({
    required String opponent,
    required String tournament,
    required String score,
    required bool hasTtd,
    required bool hasVideo,
    required String ratingText,
    required bool hasComment,
    required Color resultColor,
  }) {
    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(17)),
                child: const Icon(Icons.sports_soccer_rounded, color: _AppColors.cmrGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 17, wide: 18.2, color: _AppColors.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(tournament.isEmpty ? 'Матч' : tournament, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.3, color: _textSecondary, weight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: _AppColors.softFor(resultColor), borderRadius: BorderRadius.circular(15)),
                child: Text(score, style: _bodyStyle(size: 14.2, color: resultColor, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final twoCols = c.maxWidth >= 430;
              final gap = 8.0;
              final w = twoCols ? (c.maxWidth - gap) / 2 : c.maxWidth;
              final tiles = [
                _buildTtdReportInfoTile(Icons.check_circle_rounded, 'Статус ТТД', hasTtd ? 'Заполнено' : 'Не заполнено', hasTtd ? _AppColors.cmrGreen : _AppColors.error),
                _buildTtdReportInfoTile(Icons.play_circle_outline_rounded, 'Видео', hasVideo ? 'Есть' : 'Нет', hasVideo ? _AppColors.cmrGreen : _textTertiary),
                _buildTtdReportInfoTile(Icons.bolt_rounded, 'Оценка ТТД', ratingText.isEmpty ? '—' : '$ratingText / 10', _ttdRatingColor(ratingText)),
                _buildTtdReportInfoTile(Icons.chat_bubble_outline_rounded, 'Комментарий тренера', hasComment ? 'Есть' : 'Нет', hasComment ? _AppColors.cmrGreen : _textTertiary),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tiles.map((x) => SizedBox(width: w, child: x)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTtdReportInfoTile(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.2, color: _textSecondary, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.1, color: _textPrimary, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtdKeyIndicatorsGrid(Map<String, dynamic> match) {
    final indicators = [
      {
        'title': 'Точность передач',
        'value': _findTtdValue(const ['pass_accuracy', 'passes_accuracy', 'passing_accuracy', 'точность передач', 'точные передачи']),
        'fallback': _derivePassAccuracy(),
        'lowerBetter': false,
        'good': 75.0,
        'warn': 60.0,
      },
      {
        'title': 'Единоборства',
        'value': _findTtdValue(const ['duels', 'duels_won', 'единоборства', 'выигранные дуэли']),
        'fallback': '',
        'lowerBetter': false,
        'good': 60.0,
        'warn': 45.0,
      },
      {
        'title': 'Обводки',
        'value': _findTtdValue(const ['dribbles', 'successful_dribbles', 'обводки', 'дриблинг']),
        'fallback': '',
        'lowerBetter': false,
        'good': 60.0,
        'warn': 40.0,
      },
      {
        'title': 'Удары',
        'value': _findTtdValue(const ['shots', 'shots_on_target', 'удары', 'удары в створ']),
        'fallback': '',
        'lowerBetter': false,
        'good': 45.0,
        'warn': 25.0,
      },
      {
        'title': 'Потери мяча',
        'value': _findTtdValue(const ['losses', 'ball_losses', 'turnovers', 'потери', 'потери мяча']),
        'fallback': '',
        'lowerBetter': true,
        'good': 4.0,
        'warn': 7.0,
      },
      {
        'title': 'Перехваты',
        'value': _findTtdValue(const ['interceptions', 'перехваты', 'intercept']),
        'fallback': '',
        'lowerBetter': false,
        'good': 4.0,
        'warn': 2.0,
      },
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 3 : (c.maxWidth >= 410 ? 2 : 1);
        final gap = 9.0;
        final w = cols == 1 ? c.maxWidth : (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: indicators.map((raw) {
            final value = (_asStr(raw['value']).trim().isEmpty ? _asStr(raw['fallback']) : _asStr(raw['value'])).trim();
            final lowerBetter = raw['lowerBetter'] == true;
            final good = raw['good'] as double;
            final warn = raw['warn'] as double;
            final color = _ttdIndicatorColor(value, lowerBetter: lowerBetter, good: good, warn: warn);
            final caption = _ttdIndicatorCaption(value, lowerBetter: lowerBetter, good: good, warn: warn);
            return SizedBox(
              width: w,
              child: _buildTtdIndicatorCard(
                title: _asStr(raw['title']),
                value: value.isEmpty ? '—' : _ruTtdValue(value),
                caption: caption,
                color: color,
                lowerBetter: lowerBetter,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTtdIndicatorCard({required String title, required String value, required String caption, required Color color, required bool lowerBetter}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.8, color: _textSecondary, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 17, color: _textPrimary))),
              Icon(lowerBetter ? Icons.trending_down_rounded : Icons.trending_up_rounded, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 3),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.2, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTtdProblemZones(Map<String, dynamic> match) {
    final problems = _ttdProblems(match);
    if (problems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(16), ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, color: _AppColors.cmrGreen, size: 18),
            const SizedBox(width: 9),
            Expanded(child: Text('Критичных проблемных зон по выбранному матчу не найдено.', style: _bodyStyle(size: 11.4, color: _textPrimary, weight: FontWeight.w600))),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _AppColors.redSoft, borderRadius: BorderRadius.circular(16), ),
      child: Column(
        children: problems.map((p) {
          final last = p == problems.last;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_rounded, color: _AppColors.error, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_asStr(p['title']), style: _bodyStyle(size: 12.0, color: _AppColors.error, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_asStr(p['text']), style: _bodyStyle(size: 10.7, color: _textSecondary, weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTtdRecommendation(Map<String, dynamic> match) {
    final text = _ttdRecommendationText(match);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.flag_rounded, color: _AppColors.cmrGreen, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Рекомендация', style: _bodyStyle(size: 11.5, color: _textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(text, style: _bodyStyle(size: 11.0, color: _textPrimary, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRightDetailsPane() {
    final match = _matchDetailsSelection();
    if (match == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.sports_score_rounded,
        title: 'Детали матча',
        subtitle: 'Выберите карточку матча в центральной части.',
        child: _buildEmptyState(icon: Icons.sports_soccer_rounded, message: 'Матчей пока нет.'),
        actions: [_buildCmrEditButton(icon: Icons.add_rounded, label: 'Матч', onTap: () => _showEditMatchDialog())],
      );
    }

    final matchId = _asInt(match['match_id'] ?? match['id']);
    final opponent = _asStr(match['opponent']).trim().isEmpty ? 'Соперник не указан' : _asStr(match['opponent']).trim();
    final tournament = _asStr(match['competition_name'] ?? match['tournament'] ?? match['type']).trim();
    final date = _formatMatchDate(_asStr(match['match_date'] ?? match['date'] ?? match['start_at']));
    final score = _matchScore(match).trim().isEmpty ? '—' : _matchScore(match).trim();
    final video = _matchVideoUrl(match);
    final ttdText = _asStr(match['ttd_text']).trim();
    final notes = _matchCoachComment(match);
    final hasTtd = _hasMatchTtd(match) || _isSelectedMatchLoaded(match);
    final hasVideo = video.isNotEmpty;
    final isOpening = _openingPlayerMatchId == matchId && matchId > 0;
    final resultColor = _matchResultColor(match);
    final resultLabel = _matchResultLabel(match);

    return _buildCmrRightDetailsShell(
      icon: Icons.sports_score_rounded,
      title: opponent,
      subtitle: date.isEmpty ? 'Паспорт выбранного матча' : 'Матч за $date',
      accent: _AppColors.cmrGreen,
      actions: [_buildCmrEditButton(icon: Icons.edit_rounded, label: 'Редактировать', onTap: () => _showEditMatchDialog(match))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMatchPassportHeader(
            opponent: opponent,
            score: score,
            date: date,
            tournament: tournament,
            resultColor: resultColor,
          ),
          const SizedBox(height: 12),
          _buildMatchInfoGrid(
            date: date,
            tournament: tournament,
            hasTtd: hasTtd,
            hasVideo: hasVideo,
            resultLabel: resultLabel,
            resultColor: resultColor,
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _matchDetailTextBlock(Icons.chat_bubble_outline_rounded, 'Комментарий тренера', notes),
          ],
          if (ttdText.isNotEmpty) ...[
            const SizedBox(height: 10),
            _matchDetailTextBlock(Icons.analytics_outlined, 'ТТД игрока', ttdText),
          ],
          const SizedBox(height: 12),
          _buildMatchMaterialsPanel(hasTtd: hasTtd, hasVideo: hasVideo, hasComment: notes.isNotEmpty),
          const SizedBox(height: 12),
          _buildMatchQuickActions(matchId: matchId, match: match, video: video, isOpening: isOpening),
          if (selectedTtdMatch != null && _asInt(selectedTtdMatch!['match_id'] ?? selectedTtdMatch!['id']) == matchId) ...[
            const SizedBox(height: 12),
            _buildSelectedPlayerTtdBody(tablet: false, compact: true),
          ],
        ],
      ),
    );
  }

  Widget _buildDiaryRightDetailsPane() {
    final item = _diaryDetailsSelection();
    if (item == null) {
      return _buildCmrRightDetailsShell(
        icon: Icons.menu_book_rounded,
        title: 'Дневник игрока',
        subtitle: 'Выберите запись самооценки.',
        child: _buildEmptyState(icon: Icons.menu_book_outlined, message: 'Записей дневника пока нет.'),
      );
    }
    final rating = _asInt(item['rating']).clamp(0, 5);
    final note = _asStr(item['note']).trim();
    final title = _diaryTitle(item);
    final date = _diaryDate(item);
    return _buildCmrRightDetailsShell(
      icon: Icons.menu_book_rounded,
      title: title,
      subtitle: date.isEmpty ? 'Запись дневника' : date,
      accent: _AppColors.blue,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _matchDetailPill(Icons.star_rounded, 'Самооценка', '$rating/5', color: _AppColors.blue),
          _matchDetailPill(Icons.event_rounded, 'Дата', date.isEmpty ? '—' : date, color: _AppColors.blue),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 12),
          _noteBox(icon: Icons.sticky_note_2_outlined, title: 'Заметка игрока', text: note),
        ],
      ]),
    );
  }

  String _testingReportTypeTitle(List<Map<String, dynamic>> rows) {
    final categories = rows.map((e) => _asStr(e['category'])).where((e) => e.trim().isNotEmpty).toSet();
    if (categories.length == 1) {
      switch (categories.first) {
        case 'physical':
          return 'Физическое тестирование';
        case 'technical':
          return 'Техническое тестирование';
        case 'tactical':
          return 'Тактическое тестирование';
      }
    }
    return 'Комплексное тестирование';
  }

  String _testingResultLevelLabel(Map<String, dynamic> r) {
    final status = _firstNotEmpty([r['status'], r['grade'], r['level'], r['result_status']]).trim();
    final lower = status.toLowerCase();
    if (status.isNotEmpty) {
      if (lower.contains('норм') || lower.contains('normal')) return 'норма';
      if (lower.contains('отлич') || lower.contains('excellent')) return 'отлично';
      if (lower.contains('хорош') || lower.contains('good')) return 'хорошо';
      if (lower.contains('сред') || lower.contains('average')) return 'ниже среднего';
      if (_isTestingResultPoor(r)) return 'ниже нормы';
      return status;
    }
    return _isTestingResultPoor(r) ? 'ниже нормы' : 'норма';
  }

  Color _testingResultLevelColor(Map<String, dynamic> r) {
    if (_isTestingResultPoor(r)) return _AppColors.error;
    final label = _testingResultLevelLabel(r).toLowerCase();
    if (label.contains('сред')) return _AppColors.orange;
    if (label.contains('отлич') || label.contains('хорош')) return _AppColors.cmrGreen;
    return _AppColors.cmrGreen;
  }

  String _testingCoachName() {
    return _firstNotEmpty([
      widget.player['coach_name'],
      widget.player['coachName'],
      widget.player['trainer_name'],
      widget.player['trainerName'],
      widget.player['coach'],
      widget.player['trainer'],
    ]).trim();
  }

  String _testingRecommendationText(List<Map<String, dynamic>> rows) {
    final poor = rows.where(_isTestingResultPoor).toList();
    if (poor.isEmpty) {
      return 'Сохранить текущий режим и продолжать отслеживать динамику после тренировок и матчей.';
    }
    final titles = poor
        .map((e) => _asStr(e['title']).trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .join(' и ');
    if (titles.isEmpty) {
      return 'Усилить работу по показателям, которые отмечены ниже нормы, и повторить контрольный тест.';
    }
    return 'Усилить работу по направлению: $titles. Повторить контроль после микроцикла.';
  }

  String _testingNotesText(List<Map<String, dynamic>> rows) {
    final explicit = _firstNotEmpty([
      ...rows.map((e) => e['comment']),
      ...rows.map((e) => e['note']),
      ...rows.map((e) => e['coach_comment']),
      ...rows.map((e) => e['description']),
    ]).trim();
    if (explicit.isNotEmpty) return explicit;

    final warningCount = rows.where(_isTestingResultPoor).length;
    if (warningCount > 0) {
      return 'Есть показатели ниже нормы. Тренеру стоит разобрать причины и дать индивидуальную корректировку нагрузки.';
    }
    return 'Игрок прошёл тестирование стабильно. Данные можно использовать для сравнения следующего контрольного дня.';
  }

  Widget _buildTestingRightDetailsPane() {
    final date = _selectedTestingDay;
    final rows = playerTestingResults;
    final warningCount = rows.where(_isTestingResultPoor).length;
    final dateText = date == null ? '' : DateFormat('dd.MM.yyyy').format(date);
    final title = date == null ? 'Отчёт по тестированию' : 'Отчёт за $dateText';
    final reportType = _testingReportTypeTitle(rows);
    final subtitle = '$reportType • ${_testingStageCode()}';

    if (playerTestingLoading) {
      return _buildCmrRightDetailsShell(
        icon: Icons.fact_check_rounded,
        title: title,
        subtitle: 'Загружаю результаты игрока...',
        accent: _AppColors.blue,
        child: _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))),
      );
    }

    if (rows.isEmpty) {
      return _buildCmrRightDetailsShell(
        icon: Icons.fact_check_rounded,
        title: title,
        subtitle: date == null ? 'Выберите дату в календаре слева' : subtitle,
        accent: _AppColors.blue,
        child: _buildEmptyState(icon: Icons.fact_check_outlined, message: 'Результаты по выбранной дате не найдены.'),
      );
    }

    final coachName = _testingCoachName();

    return _buildCmrRightDetailsShell(
      icon: warningCount > 0 ? Icons.warning_amber_rounded : Icons.assignment_turned_in_rounded,
      title: title,
      subtitle: subtitle,
      accent: warningCount > 0 ? _AppColors.error : _AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _testingReportStatusChip(
                icon: warningCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                label: warningCount > 0 ? 'Есть риски' : 'Завершено',
                color: warningCount > 0 ? _AppColors.error : _AppColors.cmrGreen,
              ),
              const Spacer(),
              if (coachName.isNotEmpty)
                Flexible(
                  child: _testingReportStatusChip(
                    icon: Icons.groups_2_rounded,
                    label: 'Тренер: $coachName',
                    color: const Color(0xFF64748B),
                    soft: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Результаты тестов', style: _titleStyle(size: 15.2, color: const Color(0xFF101828))),
          const SizedBox(height: 10),
          ...rows.map(_buildTestingRightResultTile).toList(),
          const SizedBox(height: 6),
          _buildTestingRecommendationCard(warningCount: warningCount, text: _testingRecommendationText(rows)),
          const SizedBox(height: 12),
          _buildTestingNotesCard(_testingNotesText(rows)),
        ],
      ),
    );
  }

  Widget _testingReportStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    bool soft = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: soft ? const Color(0xFFF6F8FA) : color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(size: 11.2, color: color, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingRecommendationCard({required int warningCount, required String text}) {
    final danger = warningCount > 0;
    final color = danger ? _AppColors.error : _AppColors.cmrGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? _AppColors.redSoft : _AppColors.cmrSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
            child: Icon(danger ? Icons.priority_high_rounded : Icons.track_changes_rounded, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Рекомендация тренеру', style: _titleStyle(size: 13.8, color: const Color(0xFF101828)))),
                    Icon(Icons.info_outline_rounded, color: color, size: 17),
                  ],
                ),
                const SizedBox(height: 6),
                Text(text, style: _bodyStyle(size: 12.2, color: const Color(0xFF475569), weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingNotesCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Заметки', style: _titleStyle(size: 13.8, color: const Color(0xFF101828))),
          const SizedBox(height: 8),
          Text(text, style: _bodyStyle(size: 12.1, color: const Color(0xFF475569), weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTestingRightResultTile(Map<String, dynamic> r) {
    final unit = _asStr(r['unit']);
    final baseValue = _testingValueText(r['value']);
    final value = '${baseValue.isEmpty ? '—' : baseValue}${unit.isEmpty || baseValue.isEmpty ? '' : ' $unit'}';
    final category = _testingCategoryTitle(_asStr(r['category']));
    final title = _asStr(r['title']).trim().isEmpty ? 'Показатель' : _asStr(r['title']).trim();
    final isPoor = _isTestingResultPoor(r);
    final accent = _testingResultLevelColor(r);
    final level = _testingResultLevelLabel(r);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isPoor ? _AppColors.redSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() => _selectedTestingResultForDetails = Map<String, dynamic>.from(r));
            _rebuildOpenSectionSheet();
          },
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isPoor ? Colors.white : _AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(isPoor ? Icons.directions_run_rounded : Icons.speed_rounded, color: accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 13.1, color: const Color(0xFF101828), weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11, color: const Color(0xFF667085), weight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 13.2, color: const Color(0xFF101828), weight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPoor) ...[
                        Icon(Icons.warning_amber_rounded, size: 14, color: accent),
                        const SizedBox(width: 4),
                      ],
                      Text(level, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 10.4, color: accent, weight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: const Color(0xFF94A3B8), size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isTestingResultPoor(Map<String, dynamic> r) {
    final text = [
      _asStr(r['status']),
      _asStr(r['grade']),
      _asStr(r['level']),
      _asStr(r['result_status']),
      _asStr(r['value']),
    ].join(' ').toLowerCase();

    if (text.contains('плохо') ||
        text.contains('низк') ||
        text.contains('слабо') ||
        text.contains('не сдан') ||
        text.contains('неуд') ||
        text.contains('bad') ||
        text.contains('poor') ||
        text.contains('low') ||
        text.contains('fail') ||
        text.contains('critical') ||
        text.contains('red')) {
      return true;
    }

    final passed = r['passed'];
    if (passed is bool && passed == false) return true;
    if (_asStr(passed).toLowerCase() == 'false' || _asStr(passed) == '0') return true;

    final rating = _parseTestingNumber(_firstNotEmpty([r['rating'], r['score'], r['points']]));
    if (rating != null && rating > 0 && rating <= 2) return true;

    final value = _parseTestingNumber(_testingValueText(r['value']));
    if (value == null) return false;

    final badMin = _parseTestingNumber(r['bad_min']);
    final badMax = _parseTestingNumber(r['bad_max']);
    if (badMin != null && value < badMin) return true;
    if (badMax != null && value > badMax) return true;

    final normMin = _parseTestingNumber(r['norm_min']);
    final normMax = _parseTestingNumber(r['norm_max']);
    final direction = _asStr(r['direction']).toLowerCase();
    final lowerIsBetter = direction.contains('lower') ||
        direction.contains('less') ||
        direction.contains('min') ||
        direction.contains('ниже') ||
        direction.contains('меньше');

    if (lowerIsBetter) {
      if (normMax != null && value > normMax) return true;
    } else {
      if (normMin != null && value < normMin) return true;
    }

    return false;
  }

  double? _parseTestingNumber(dynamic raw) {
    final s = _asStr(raw).replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  Widget _buildExportRightDetailsPane() {
    return _buildCmrRightDetailsShell(
      icon: Icons.picture_as_pdf_rounded,
      title: 'Экспорт карточки',
      subtitle: 'Сводная PDF-карточка игрока',
      accent: _AppColors.error,
      actions: [_buildCmrEditButton(icon: Icons.picture_as_pdf_rounded, label: 'Сформировать PDF', onTap: _exportPlayerPdf)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _matchDetailPill(Icons.query_stats_rounded, 'Метрики', '${metrics.length}', color: _AppColors.cmrGreen),
          _matchDetailPill(Icons.medical_information_outlined, 'Медкарта', '${medicalRecords.length}', color: _AppColors.cmrGreen),
          _matchDetailPill(Icons.sports_score_outlined, 'Матчи', '${matches.length}', color: _AppColors.cmrGreen),
          _matchDetailPill(Icons.menu_book_outlined, 'Дневник', '${diaryItems.length}', color: _AppColors.cmrGreen),
        ]),
        const SizedBox(height: 12),
        _matchDetailTextBlock(Icons.info_outline_rounded, 'Подсказка', 'Экспорт собирает профиль, показатели, медкарту, тренировки, матчи и дневник в единый документ.'),
      ]),
    );
  }

  Widget _buildCmrWorkspaceWithInlineEditor({required _CategoryTab tab, required bool compact}) {
    final leftFlex = compact ? 6 : 7;
    final editorWidth = compact ? 470.0 : 540.0;

    return Row(
      key: const ValueKey('player-workspace-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: leftFlex,
          child: _buildCmrWorkspaceContent(tab: tab, compact: true),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: editorWidth,
          child: _buildInlinePlayerEditorPanel(),
        ),
      ],
    );
  }

  Widget _buildInlinePlayerEditorPanel() {
    final name = _cmrFullName();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAF9),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _AppColors.cmrSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.edit_rounded, color: _AppColors.cmrGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Редактор игрока',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 14.6,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Закрыть редактор',
                  child: IconButton(
                    onPressed: () => _closePlayerEditorPanel(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _CmrPlayerInlineEditor(
              player: widget.player,
              onSave: _savePlayerEditorFields,
              onSaved: () => _closePlayerEditorPanel(refresh: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmrCenterPane(_CategoryTab tab) {
    if (tab.index == 0) {
      return _buildGeneralCenterInfoPane();
    }
    return _buildCmrGuidePane(tab);
  }

  Widget _buildCmrDetailsPane(_CategoryTab tab) {
    if (tab.index == 0) return _buildGeneralDetailsActionsPane();
    return _buildTabContentByIndex(tab.index);
  }

  // =============================
  // ОБЗОР ИГРОКА КАК РАБОЧИЙ ДАШБОРД
  // =============================
  Widget _buildOverviewDashboardWorkspace({required bool compact}) {
    final width = MediaQuery.of(context).size.width;
    final rightWidth = width >= 1500 ? 330.0 : (width >= 1280 ? 315.0 : 300.0);

    return Row(
      key: const ValueKey('player-overview-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildOverviewDashboardMainPane()),
        const SizedBox(width: 12),
        SizedBox(width: rightWidth, child: _buildOverviewDashboardRightPane()),
      ],
    );
  }

  Widget _buildOverviewDashboardMainPane() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      physics: const BouncingScrollPhysics(),
      children: _buildOverviewMainChildren(),
    );
  }

  Widget _buildOverviewDashboardRightPane() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      physics: const BouncingScrollPhysics(),
      children: _buildOverviewRightChildren(),
    );
  }

  List<Widget> _buildOverviewMainChildren() {
    return [
      _buildOverviewHeroCard(),
      const SizedBox(height: 12),
      _buildOverviewIndicatorsGrid(),
      const SizedBox(height: 12),
      _buildOverviewTrainingLoadCard(),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOverviewEventsCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildOverviewDynamicsCard()),
              ],
            );
          }
          return Column(
            children: [
              _buildOverviewEventsCard(),
              const SizedBox(height: 12),
              _buildOverviewDynamicsCard(),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildOverviewRightChildren() {
    return [
      _buildOverviewQuickActionsCard(),
      const SizedBox(height: 12),
      _buildOverviewWarningsCard(),
      const SizedBox(height: 12),
      _buildOverviewCoachRecommendationCard(),
      const SizedBox(height: 12),
      _buildOverviewPassportCard(),
    ];
  }

  Widget _buildOverviewHeroCard() {
    final photo = _normalizeImage(widget.player['photo']);
    final name = _cmrFullName();
    final position = _firstNotEmpty([widget.player['position'], widget.player['player_position'], widget.player['role']]);
    final number = _firstNotEmpty([widget.player['jersey_number'], widget.player['number'], widget.player['player_number']]);
    final age = _playerAge();
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']]) : _playerClub();
    final readiness = _profileReadinessPercent();
    final warnings = _overviewWarningRows();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final header = Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _buildPhotoPreviewTap(
                  imageUrl: photo,
                  child: _buildCircleNetworkImage(
                    imageUrl: photo,
                    size: compact ? 72 : 96,
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fallback: const Icon(Icons.person_rounded, color: _AppColors.cmrGreen),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: compact ? 20 : 24, height: 1.04, fontWeight: FontWeight.w700, letterSpacing: -.35),
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildOverviewChip(Icons.sports_soccer_rounded, position.isEmpty ? 'Амплуа не указано' : position, _AppColors.cmrGreen),
                        _buildOverviewChip(Icons.tag_rounded, number.isEmpty ? '№ —' : '№ $number', _AppColors.textSecondary),
                        _buildOverviewChip(Icons.cake_rounded, age.isEmpty ? 'Возраст —' : '$age лет', _AppColors.textSecondary),
                        if (team.isNotEmpty) _buildOverviewChip(Icons.groups_2_rounded, team, _AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final profile = _buildOverviewReadinessBlock(readiness);
          final status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewStatusLine(Icons.monitor_heart_rounded, 'Форма:', _overviewFormLabel().toLowerCase(), _overviewFormColor()),
              const SizedBox(height: 12),
              _buildOverviewStatusLine(Icons.schedule_rounded, 'Последняя активность:', _overviewLastActivityLabel(), _AppColors.cmrGreen),
              const SizedBox(height: 12),
              _buildOverviewStatusLine(Icons.health_and_safety_rounded, 'Риск:', warnings.isEmpty ? 'нет предупреждений' : '${warnings.length} предупрежд.', warnings.isEmpty ? _AppColors.cmrGreen : _AppColors.error),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 18),
                profile,
                const SizedBox(height: 16),
                status,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 56, child: header),
              _buildOverviewVerticalDivider(),
              Expanded(flex: 18, child: profile),
              _buildOverviewVerticalDivider(),
              Expanded(flex: 28, child: status),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewIndicatorsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 560 ? 2 : 1);
        final gap = 10.0;
        final itemWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = <Widget>[
          _buildOverviewFormCard(),
          _buildOverviewGameIndicatorsCard(),
          _buildOverviewTestingCard(),
          _buildOverviewAttendanceCard(),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((child) => SizedBox(width: itemWidth, child: child)).toList(),
        );
      },
    );
  }

  Widget _buildOverviewFormCard() {
    final readiness = _overviewReadinessPercent();
    return _buildOverviewMetricCard(
      icon: Icons.monitor_heart_rounded,
      title: 'Форма игрока',
      onTap: () => setState(() => _selectedTabIndex = 51),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_overviewFormLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewTitleStyle(size: 18, color: _overviewFormColor())),
                  const SizedBox(height: 4),
                  Text('Форма', style: _overviewLabelStyle()),
                ]),
              ),
              SizedBox(width: 78, height: 34, child: CustomPaint(painter: _OverviewLinePainter(values: _overviewTrendValues(), color: _overviewFormColor(), fill: false))),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _buildOverviewSmallValue('Усталость', _overviewFatigueLabel())),
              Expanded(child: _buildOverviewSmallValue('Готовность', '$readiness%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGameIndicatorsCard() {
    return _buildOverviewMetricCard(
      icon: Icons.sports_soccer_rounded,
      title: 'Игровые показатели',
      onTap: () async {
        setState(() => _selectedTabIndex = 5);
        await _loadMatches(force: false);
      },
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _buildOverviewBigValue('${matches.length}', 'Матчи')),
            Expanded(child: _buildOverviewBigValue(_overviewAverageScoreText(), 'Средняя оценка')),
          ]),
          const SizedBox(height: 13),
          Container(height: 1, color: const Color(0xFFE9EEF2)),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: _buildOverviewBigValue(_overviewFootballMetric(['гол', 'goals'], fallback: '—'), 'Голы')),
            Expanded(child: _buildOverviewBigValue(_overviewFootballMetric(['передач', 'ассист', 'assist'], fallback: '—'), 'Голевые передачи')),
          ]),
        ],
      ),
    );
  }

  Widget _buildOverviewTestingCard() {
    final score = _overviewTestingScoreText();
    final latest = _overviewTestingLastDateText();
    final poorCount = playerTestingResults.where(_isTestingResultPoor).length;
    return _buildOverviewMetricCard(
      icon: Icons.show_chart_rounded,
      title: 'Тестирование',
      onTap: () async {
        setState(() => _selectedTabIndex = 7);
        await _loadPlayerTestingHistory(force: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildOverviewBigValue(score, latest.isEmpty ? 'Последний тест' : 'Последний тест ($latest)')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: poorCount > 0 ? _AppColors.redSoft : _AppColors.cmrSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(poorCount > 0 ? 'Внимание' : 'Хорошо', style: TextStyle(fontFamily: _fontFamily, color: poorCount > 0 ? _AppColors.error : _AppColors.cmrGreen, fontSize: 10.1, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(height: 1, color: const Color(0xFFE9EEF2)),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: _buildOverviewBigValue(_overviewFootballMetric(['скорост', 'speed'], fallback: '—'), 'Скоростные качества')),
            Expanded(child: _buildOverviewBigValue(_overviewFootballMetric(['вынослив', 'endurance'], fallback: '—'), 'Выносливость')),
          ]),
        ],
      ),
    );
  }

  Widget _buildOverviewAttendanceCard() {
    final rate = _overviewAttendancePercent();
    final missed = _overviewAttendanceMissedCount();
    final sick = _overviewAttendanceSickCount();
    return _buildOverviewMetricCard(
      icon: Icons.calendar_month_rounded,
      title: 'Посещаемость',
      onTap: () async {
        setState(() => _selectedTabIndex = 52);
        await _loadTrainingSectionData(force: true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rate == null ? '—' : '$rate%', style: _overviewTitleStyle(size: 21, color: _AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Посещаемость', style: _overviewLabelStyle()),
          const SizedBox(height: 12),
          SizedBox(height: 34, child: CustomPaint(painter: _OverviewLinePainter(values: _overviewAttendanceTrendValues(), color: _AppColors.cmrGreen, fill: false), child: const SizedBox.expand())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildOverviewSmallValue('Пропущено', missed == 1 ? '1 тренировка' : '$missed тренировки', valueColor: missed > 0 ? _AppColors.error : _AppColors.textPrimary)),
            Expanded(child: _buildOverviewSmallValue('Из-за болезни', '$sick', valueColor: sick > 0 ? _AppColors.error : _AppColors.textPrimary)),
          ]),
        ],
      ),
    );
  }

  Widget _buildOverviewTrainingLoadCard() {
    final minutes = _overviewTrainingMinutes();
    final intensity = _overviewTrainingIntensityText();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final left = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewIconBox(Icons.bar_chart_rounded, _AppColors.cmrGreen),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Тренировочная нагрузка', maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewSectionTitleStyle()),
                  const SizedBox(height: 14),
                  Text(_overviewLoadLabel(), style: _overviewTitleStyle(size: 15.5, color: _AppColors.orange)),
                ]),
              ),
            ],
          );
          final chart = SizedBox(height: 48, child: _buildOverviewBarStrip(_overviewLoadBars(), _AppColors.orange));
          final values = Row(children: [
            Expanded(child: _buildOverviewSmallValue('Объём', minutes > 0 ? '$minutes мин' : '—')),
            Expanded(child: _buildOverviewSmallValue('Интенсивность', intensity)),
          ]);
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 14), chart, const SizedBox(height: 12), values]);
          }
          return Row(children: [Expanded(flex: 44, child: left), Expanded(flex: 34, child: chart), const SizedBox(width: 16), Expanded(flex: 26, child: values)]);
        },
      ),
    );
  }

  Widget _buildOverviewEventsCard() {
    final events = _overviewRecentEvents().take(5).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Последние события', style: _overviewSectionTitleStyle()),
          const SizedBox(height: 14),
          if (events.isEmpty)
            _buildOverviewEmpty('Нет последних событий. Когда появятся тренировки, матчи или тесты — они будут здесь.')
          else
            ...List.generate(events.length, (i) => _buildOverviewEventRow(events[i], last: i == events.length - 1)),
          const SizedBox(height: 8),
          _buildOverviewTextAction('Показать все события', Icons.chevron_right_rounded, () async {
            setState(() => _selectedTabIndex = 4);
            await _loadTrainingSectionData(force: true);
          }),
        ],
      ),
    );
  }

  Widget _buildOverviewDynamicsCard() {
    final poor = playerTestingResults.where(_isTestingResultPoor).length;
    final strengths = _overviewStrengths();
    final growth = _overviewGrowthZones();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Динамика игрока', style: _overviewSectionTitleStyle())),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Text('Последние 8 недель', style: TextStyle(color: _AppColors.textSecondary, fontSize: 10.1, fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary, size: 16),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _buildOverviewSegment('Физика', false),
            _buildOverviewSegment('Техника', true),
            _buildOverviewSegment('Психология', false),
          ]),
          const SizedBox(height: 16),
          SizedBox(height: 142, child: CustomPaint(painter: _OverviewTrendPainter(values: _overviewTrendValues(), color: _AppColors.cmrGreen), child: const SizedBox.expand())),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            final left = _buildOverviewListBox('Сильные стороны', strengths, _AppColors.cmrGreen);
            final right = _buildOverviewListBox(poor > 0 ? 'Зоны риска' : 'Зоны роста', growth, _AppColors.orange);
            if (compact) return Column(children: [left, const SizedBox(height: 10), right]);
            return Row(children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)]);
          }),
          const SizedBox(height: 10),
          _buildOverviewTextAction('Полный анализ игрока', Icons.chevron_right_rounded, () => setState(() => _selectedTabIndex = 51)),
        ],
      ),
    );
  }

  Widget _buildOverviewQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Быстрые действия', style: _overviewSectionTitleStyle()),
        const SizedBox(height: 14),
        _buildOverviewQuickAction(Icons.chat_bubble_rounded, 'Сообщение', 'Написать игроку или родителям', _AppColors.cmrGreen, _openPrivateChat),
        const SizedBox(height: 8),
        _buildOverviewQuickAction(Icons.edit_rounded, 'Рабочая карточка', 'Открыть рабочую карточку', _AppColors.blue, _openPlayerEditorPanel),
        const SizedBox(height: 8),
        _buildOverviewQuickAction(Icons.construction_rounded, 'Назначить тренировку', 'Создать персональное задание', _AppColors.orange, _assignTraining),
      ]),
    );
  }

  Widget _buildOverviewWarningsCard() {
    final rows = _overviewWarningRows();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Предупреждения', style: _overviewSectionTitleStyle()),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          _buildOverviewWarningRow(Icons.check_circle_rounded, 'Критичных предупреждений нет', 'Профиль в норме', _AppColors.cmrGreen, null)
        else
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
              child: _buildOverviewWarningRow(row['icon'] as IconData, row['title'] as String, row['subtitle'] as String, row['color'] as Color, row['onTap'] as VoidCallback?),
            );
          }),
      ]),
    );
  }

  Widget _buildOverviewCoachRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _buildOverviewIconBox(Icons.article_outlined, _AppColors.cmrGreen, size: 38),
          const SizedBox(width: 10),
          Expanded(child: Text('Рекомендация тренеру', style: _overviewSectionTitleStyle())),
        ]),
        const SizedBox(height: 14),
        Text(_overviewCoachRecommendationText(), style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 11.3, height: 1.45, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildOverviewPassportCard() {
    final age = _playerAge();
    final birth = _formatOverviewDate(_playerBirthDate());
    final citizenship = _firstNotEmpty([widget.player['nationality'], widget.player['country'], widget.player['citizenship']]);
    final height = _firstNotEmpty([widget.player['height'], widget.player['player_height']]);
    final weight = _firstNotEmpty([widget.player['weight'], widget.player['player_weight']]);
    final foot = _firstNotEmpty([widget.player['foot'], widget.player['preferred_foot'], widget.player['working_foot']]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCardDecoration(radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Паспорт игрока', style: _overviewSectionTitleStyle()),
        const SizedBox(height: 14),
        _buildOverviewPassportRow('Возраст', age.isEmpty ? '—' : '$age лет'),
        _buildOverviewPassportRow('Дата рождения', birth.isEmpty ? '—' : birth),
        _buildOverviewPassportRow('Гражданство', citizenship.isEmpty ? '—' : citizenship),
        _buildOverviewPassportRow('Рост / Вес', '${height.isEmpty ? '—' : _appendUnit(height, 'см')} / ${weight.isEmpty ? '—' : _appendUnit(weight, 'кг')}'),
        _buildOverviewPassportRow('Рабочая нога', foot.isEmpty ? '—' : foot),
      ]),
    );
  }

  Widget _buildOverviewMetricCard({required IconData icon, required String title, required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 190),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: _overviewCardDecoration(radius: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: _AppColors.accentForIcon(icon), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewSectionTitleStyle(size: 14.2))),
                const Icon(Icons.chevron_right_rounded, color: _AppColors.textTertiary, size: 22),
              ]),
              const SizedBox(height: 16),
              child,
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewQuickAction(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: null,
          ),
          child: Row(children: [
            _buildOverviewIconBox(icon, color == _AppColors.cmrGreen ? color : _AppColors.textPrimary, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: color, fontSize: 11.9, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w700)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: _AppColors.textTertiary, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverviewWarningRow(IconData icon, String title, String subtitle, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: null,
          ),
          child: Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: color == _AppColors.error ? _AppColors.error : const Color(0xFF111418), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 15)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: color, fontSize: 11.4, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.4, height: 1.2, fontWeight: FontWeight.w700)),
            ])),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: _AppColors.textTertiary, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverviewEventRow(Map<String, dynamic> event, {required bool last}) {
    final color = event['color'] as Color;
    final date = event['date'] as DateTime?;
    final title = event['title'] as String;
    final subtitle = event['subtitle'] as String;
    final icon = event['icon'] as IconData;
    final onTap = event['onTap'] as VoidCallback?;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.only(top: 10, bottom: last ? 10 : 12),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: 11.9, fontWeight: FontWeight.w700, height: 1.1)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.9, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 10),
            Text(_overviewDateLabel(date), textAlign: TextAlign.right, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.5, height: 1.18, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverviewSmallValue(String label, String value, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewLabelStyle()),
      const SizedBox(height: 5),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: valueColor ?? _AppColors.textPrimary, fontSize: 11.2, fontWeight: FontWeight.w700, height: 1.1)),
    ]);
  }

  Widget _buildOverviewBigValue(String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewTitleStyle(size: 20.5, color: _AppColors.textPrimary)),
      const SizedBox(height: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _overviewLabelStyle()),
    ]);
  }

  Widget _buildOverviewReadinessBlock(int percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$percent%', style: TextStyle(fontFamily: _fontFamily, color: _AppColors.cmrGreen, fontSize: 20.6, height: 1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text('заполнено', style: _overviewLabelStyle()),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 100) / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE9EEF2),
            valueColor: const AlwaysStoppedAnimation<Color>(_AppColors.cmrGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStatusLine(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 17),
      const SizedBox(width: 8),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: 10.7, fontWeight: FontWeight.w700)),
      const SizedBox(width: 5),
      Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: color, fontSize: 10.7, fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildOverviewChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.7, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildOverviewVerticalDivider() {
    return const SizedBox(width: 28);
  }

  Widget _buildOverviewIconBox(IconData icon, Color color, {double size = 42}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(size * .36)),
      child: Icon(icon, color: color, size: size * .48),
    );
  }

  Widget _buildOverviewBarStrip(List<double> values, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((v) {
        final h = (10 + (v.clamp(0, 1) * 34)).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(height: h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverviewSegment(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: active ? _AppColors.cmrSoft : Colors.white, borderRadius: BorderRadius.circular(12), ),
      child: Text(label, style: TextStyle(fontFamily: _fontFamily, color: active ? _AppColors.cmrGreen : _AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildOverviewListBox(String title, List<String> rows, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _AppColors.softFor(color), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontFamily: _fontFamily, color: color, fontSize: 11.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        ...rows.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: color, size: 14),
                const SizedBox(width: 7),
                Expanded(child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: 10.7, fontWeight: FontWeight.w600))),
              ]),
            )),
      ]),
    );
  }

  Widget _buildOverviewTextAction(String label, IconData icon, VoidCallback onTap) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: _AppColors.cmrGreen),
        label: Text(label, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.cmrGreen, fontSize: 11.3, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildOverviewEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAF9), borderRadius: BorderRadius.circular(18)),
      child: Text(text, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 11.4, height: 1.35, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildOverviewPassportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: 11.3, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  BoxDecoration _overviewCardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.028),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }


  TextStyle _overviewSectionTitleStyle({double size = 14.6}) {
    return TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: size, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -.1);
  }

  TextStyle _overviewTitleStyle({required double size, required Color color}) {
    return TextStyle(fontFamily: _fontFamily, color: color, fontSize: size, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -.25);
  }

  TextStyle _overviewLabelStyle() {
    return TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: 10.4, height: 1.1, fontWeight: FontWeight.w600);
  }

  String _overviewFormLabel() {
    final avg = _overviewAverageScore();
    if (avg >= 8.2) return 'Отличная';
    if (avg >= 6.5) return 'Хорошая';
    if (avg >= 5.0) return 'Средняя';
    if (avg > 0) return 'Снижена';
    final readiness = _profileReadinessPercent();
    if (readiness >= 80) return 'Хорошая';
    if (readiness >= 60) return 'Средняя';
    return 'Требует внимания';
  }

  Color _overviewFormColor() {
    final label = _overviewFormLabel().toLowerCase();
    if (label.contains('снижен') || label.contains('вним')) return _AppColors.error;
    if (label.contains('сред')) return _AppColors.orange;
    return _AppColors.cmrGreen;
  }

  int _overviewReadinessPercent() {
    final metric = _overviewFootballMetric(['готовность', 'readiness'], fallback: '');
    final parsed = _parseOverviewNumber(metric);
    if (parsed != null) return parsed.round().clamp(0, 100);
    return _profileReadinessPercent();
  }

  String _overviewFatigueLabel() {
    final value = _overviewFootballMetric(['устал', 'fatigue'], fallback: '');
    if (value.isNotEmpty) return value;
    final missed = _overviewAttendanceMissedCount();
    if (missed >= 3) return 'Повышенная';
    return 'Низкая';
  }

  String _overviewAverageScoreText() {
    final avg = _overviewAverageScore();
    if (avg <= 0) return '—';
    return avg.toStringAsFixed(1).replaceAll('.', ',');
  }

  double _overviewAverageScore() {
    final values = <int>[];
    for (final row in attendanceLog) {
      final value = _firstRatingValue(row, _coachRatingKeys);
      if (value is int) values.add(value);
    }
    if (values.isEmpty) {
      for (final row in diaryItems) {
        final value = _firstRatingValue(row, _playerRatingKeys);
        if (value is int) values.add(value);
      }
    }
    if (values.isEmpty) return 0;
    final avgFive = values.reduce((a, b) => a + b) / values.length;
    return (avgFive * 2).clamp(0, 10).toDouble();
  }

  String _overviewFootballMetric(List<String> aliases, {String fallback = '—'}) {
    for (final raw in metrics) {
      final parsed = _splitMetricLine(raw);
      final title = (parsed['title'] ?? '').toLowerCase();
      final value = (parsed['value'] ?? '').trim();
      if (value.isEmpty) continue;
      for (final alias in aliases) {
        if (title.contains(alias.toLowerCase())) return value;
      }
    }
    final sportData = _asStr(widget.player['sport_data'] ?? widget.player['sports_data']);
    if (sportData.trim().isNotEmpty) {
      for (final line in sportData.split('\n')) {
        final parsed = _splitMetricLine(line);
        final title = (parsed['title'] ?? '').toLowerCase();
        final value = (parsed['value'] ?? '').trim();
        if (value.isEmpty) continue;
        for (final alias in aliases) {
          if (title.contains(alias.toLowerCase())) return value;
        }
      }
    }
    return fallback;
  }

  int? _overviewAttendancePercent() {
    final rows = attendanceLog;
    if (rows.isNotEmpty) {
      var good = 0;
      var total = 0;
      for (final row in rows) {
        final status = _attendanceStatusOf(row);
        if (status.isEmpty) continue;
        total++;
        if (status == 'present' || status == 'late' || status == 'individual') good++;
      }
      if (total > 0) return ((good / total) * 100).round().clamp(0, 100);
    }
    final fromMetric = _parseOverviewNumber(_overviewFootballMetric(['посещаемость', 'attendance'], fallback: ''));
    return fromMetric == null ? null : fromMetric.round().clamp(0, 100);
  }

  int _overviewAttendanceMissedCount() {
    return attendanceLog.where((row) {
      final status = _attendanceStatusOf(row);
      return status == 'absent' || status == 'injured' || status == 'sick';
    }).length;
  }

  int _overviewAttendanceSickCount() {
    return attendanceLog.where((row) {
      final status = _attendanceStatusOf(row);
      final reason = _firstNotEmpty([row['reason'], row['absence_reason'], row['status_reason']]).toLowerCase();
      return status == 'sick' || reason.contains('болез') || reason.contains('sick');
    }).length;
  }

  List<double> _overviewAttendanceTrendValues() {
    final rows = List<Map<String, dynamic>>.from(attendanceLog);
    rows.sort((a, b) => (_parseEventDate(a) ?? DateTime(1970)).compareTo(_parseEventDate(b) ?? DateTime(1970)));
    final values = <double>[];
    for (final row in rows.take(12)) {
      final status = _attendanceStatusOf(row);
      if (status == 'present' || status == 'late' || status == 'individual') values.add(8.0);
      if (status == 'absent' || status == 'sick' || status == 'injured') values.add(4.0);
    }
    if (values.length >= 3) return values;
    final rate = (_overviewAttendancePercent() ?? 82) / 10.0;
    return [rate - .6, rate - .2, rate, rate - .1, rate + .3, rate + .1, rate + .2, rate + .6].map((e) => e.clamp(0, 10).toDouble()).toList();
  }

  int _overviewTrainingMinutes() {
    var total = 0;
    final rows = _dedupeAndEnrichTrainingRows([...teamEvents, ...attendanceLog]);
    for (final row in rows) {
      final direct = _parseOverviewNumber(_firstNotEmpty([row['duration'], row['duration_minutes'], row['minutes'], row['training_duration']]));
      if (direct != null) {
        total += direct.round();
        continue;
      }
      final start = DateTime.tryParse(_firstNotEmpty([row['start_at'], row['start_time']]).replaceAll(' ', 'T'));
      final end = DateTime.tryParse(_firstNotEmpty([row['end_at'], row['end_time']]).replaceAll(' ', 'T'));
      if (start != null && end != null && end.isAfter(start)) total += end.difference(start).inMinutes;
    }
    return total;
  }

  String _overviewTrainingIntensityText() {
    final value = _overviewFootballMetric(['интенсив', 'intensity'], fallback: '');
    if (value.isNotEmpty) return value.contains('/') ? value : '$value / 10';
    final avg = _overviewAverageScore();
    if (avg > 0) return '${avg.toStringAsFixed(1).replaceAll('.', ',')} / 10';
    return '—';
  }

  String _overviewLoadLabel() {
    final minutes = _overviewTrainingMinutes();
    if (minutes >= 720) return 'Высокая';
    if (minutes >= 360) return 'Средняя';
    if (minutes > 0) return 'Низкая';
    return 'Нет данных';
  }

  List<double> _overviewLoadBars() {
    final rows = _dedupeAndEnrichTrainingRows([...teamEvents, ...attendanceLog]);
    if (rows.length >= 8) {
      return rows.take(12).map((row) {
        final intensity = _parseOverviewNumber(_firstNotEmpty([row['intensity'], row['load'], row['rating']])) ?? 5;
        return (intensity / 10).clamp(.18, 1).toDouble();
      }).toList();
    }
    return const [.24, .34, .46, .78, .56, .42, .62, .58, .72, .90, .78, .64];
  }

  List<double> _overviewTrendValues() {
    final values = <double>[];
    for (final r in playerTestingResults) {
      final rating = _parseTestingNumber(_firstNotEmpty([r['rating'], r['score'], r['points']]));
      if (rating != null && rating > 0) values.add(rating <= 5 ? rating * 2 : rating);
    }
    if (values.length < 3) {
      for (final row in attendanceLog) {
        final rating = _firstRatingValue(row, _coachRatingKeys);
        if (rating is int) values.add(rating * 2.0);
      }
    }
    if (values.length >= 3) return values.take(10).map((e) => e.clamp(0, 10).toDouble()).toList();
    final base = (_profileReadinessPercent() / 10).clamp(4, 8).toDouble();
    return [base - .4, base, base + .2, base + .1, base + .4, base - .1, base + .2, base - .2, base + .1, base + .5].map((e) => e.clamp(0, 10).toDouble()).toList();
  }

  String _overviewTestingScoreText() {
    final ratings = playerTestingResults.map((r) => _parseTestingNumber(_firstNotEmpty([r['rating'], r['score'], r['points']]))).whereType<double>().toList();
    if (ratings.isEmpty) return '— / 10';
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    final normalized = avg <= 5 ? avg * 2 : avg;
    return '${normalized.toStringAsFixed(1).replaceAll('.', ',')} / 10';
  }

  String _overviewTestingLastDateText() {
    final dates = playerTestingResults.map(_testingDateOf).whereType<DateTime>().toList();
    if (dates.isEmpty) return '';
    dates.sort((a, b) => b.compareTo(a));
    return DateFormat('dd.MM').format(dates.first);
  }

  List<Map<String, dynamic>> _overviewRecentEvents() {
    final rows = <Map<String, dynamic>>[];
    final trainings = _dedupeAndEnrichTrainingRows([...teamEvents, ...attendanceLog]);
    for (final row in trainings.take(8)) {
      final status = _attendanceStatusOf(row);
      final missed = status == 'absent' || status == 'sick' || status == 'injured';
      rows.add({
        'date': _parseEventDate(row),
        'title': missed ? 'Тренировка пропущена' : 'Тренировка завершена',
        'subtitle': missed ? _firstNotEmpty([row['reason'], row['absence_reason'], 'Причина не указана']) : _firstNotEmpty([row['title'], row['event_title'], row['name'], 'Командная тренировка']),
        'icon': missed ? Icons.close_rounded : Icons.check_rounded,
        'color': missed ? _AppColors.error : _AppColors.cmrGreen,
        'onTap': () { _selectTrainingForDetails(row); },
      });
    }
    for (final match in matches.take(5)) {
      rows.add({
        'date': _matchDateOf(match),
        'title': 'Матч завершён',
        'subtitle': _firstNotEmpty([match['title'], match['opponent'], match['name'], 'Игровая история']),
        'icon': Icons.sports_soccer_rounded,
        'color': _AppColors.blue,
        'onTap': () { _selectMatchForDetails(match, loadTtd: false); },
      });
    }
    if (playerTestingResults.isNotEmpty) {
      rows.add({
        'date': _testingDateOf(playerTestingResults.first),
        'title': 'Результат тестирования',
        'subtitle': _firstNotEmpty([playerTestingResults.first['title'], playerTestingResults.first['name'], 'Контрольные показатели']),
        'icon': Icons.show_chart_rounded,
        'color': _AppColors.cmrGreen,
        'onTap': () {
          setState(() => _selectedTabIndex = 7);
          _loadPlayerTestingHistory(force: false);
        },
      });
    }
    if (medicalRecords.isNotEmpty) {
      final m = medicalRecords.first;
      rows.add({
        'date': _diaryDateOf(m),
        'title': 'Медицинское обновление',
        'subtitle': _firstNotEmpty([m['title'], m['type'], 'Плановая проверка']),
        'icon': Icons.favorite_rounded,
        'color': _AppColors.orange,
        'onTap': () => setState(() => _selectedTabIndex = 3),
      });
    }
    rows.sort((a, b) => ((b['date'] as DateTime?) ?? DateTime(1970)).compareTo((a['date'] as DateTime?) ?? DateTime(1970)));
    return rows;
  }

  List<Map<String, dynamic>> _overviewWarningRows() {
    final rows = <Map<String, dynamic>>[];
    final attendance = _overviewAttendancePercent();
    if (attendance != null && attendance < 85) {
      rows.add({
        'icon': Icons.priority_high_rounded,
        'title': 'Посещаемость: $attendance%',
        'subtitle': 'Ниже нормы (мин. 85%)',
        'color': _AppColors.error,
        'onTap': () {
          setState(() => _selectedTabIndex = 52);
          _loadTrainingSectionData(force: true);
        },
      });
    }
    final poor = playerTestingResults.where(_isTestingResultPoor).length;
    if (poor > 0) {
      rows.add({
        'icon': Icons.warning_amber_rounded,
        'title': poor == 1 ? 'Слабая зона в тестировании' : 'Слабые зоны в тестировании',
        'subtitle': poor == 1 ? 'Один показатель ниже нормы' : '$poor показателя ниже нормы',
        'color': _AppColors.orange,
        'onTap': () {
          setState(() => _selectedTabIndex = 7);
          _loadPlayerTestingHistory(force: false);
        },
      });
    }
    final readiness = _profileReadinessPercent();
    if (readiness < 80) {
      rows.add({
        'icon': Icons.info_rounded,
        'title': 'Профиль заполнен на $readiness%',
        'subtitle': 'Проверьте недостающие данные',
        'color': _AppColors.textSecondary,
        'onTap': _openPlayerEditorPanel,
      });
    }
    return rows.take(3).toList();
  }

  String _overviewCoachRecommendationText() {
    final warnings = _overviewWarningRows();
    final poor = playerTestingResults.where(_isTestingResultPoor).length;
    if (poor > 0) {
      return '${_cmrFullName()} требует внимания по тестированию: есть показатели ниже нормы. Рекомендуется добавить индивидуальный блок на выносливость, скорость и контроль точности под нагрузкой.';
    }
    final attendance = _overviewAttendancePercent();
    if (attendance != null && attendance < 85) {
      return '${_cmrFullName()} пропустил часть занятий. Рекомендуется уточнить причины пропусков и постепенно вернуть игрока к полной тренировочной нагрузке.';
    }
    if (warnings.isEmpty) {
      return '${_cmrFullName()} стабильно выглядит по текущим данным. Можно усилить игровые задачи, контроль передач под давлением и работу без мяча.';
    }
    return 'Проверьте предупреждения выше и обновите недостающие данные профиля, чтобы рекомендации по игроку стали точнее.';
  }

  List<String> _overviewStrengths() {
    final out = <String>[];
    for (final alias in const ['скорост', 'гол', 'ата', 'техник', 'работа без мяча']) {
      final value = _overviewFootballMetric([alias], fallback: '');
      if (value.isNotEmpty && out.length < 3) {
        if (alias == 'скорост') out.add('Скорость');
        if (alias == 'гол') out.add('Игра в атаке');
        if (alias == 'ата') out.add('Игра в атаке');
        if (alias == 'техник') out.add('Техника');
        if (alias == 'работа без мяча') out.add('Работа без мяча');
      }
    }
    if (out.isEmpty) out.addAll(const ['Скорость', 'Игра в атаке', 'Работа без мяча']);
    return out.toSet().take(3).toList();
  }

  List<String> _overviewGrowthZones() {
    final poorRows = playerTestingResults.where(_isTestingResultPoor).map((r) => _firstNotEmpty([r['title'], r['name'], r['code']])).where((e) => e.isNotEmpty).toList();
    if (poorRows.isNotEmpty) return poorRows.take(3).toList();
    return const ['Выносливость', 'Точность передач', 'Игра головой'];
  }

  String _overviewLastActivityLabel() {
    final dates = <DateTime>[];
    for (final row in [...teamEvents, ...attendanceLog]) {
      final d = _parseEventDate(Map<String, dynamic>.from(row));
      if (d != null) dates.add(d);
    }
    for (final row in matches) {
      final d = _matchDateOf(row);
      if (d != null) dates.add(d);
    }
    for (final row in playerTestingResults) {
      final d = _testingDateOf(row);
      if (d != null) dates.add(d);
    }
    if (dates.isEmpty) return 'нет данных';
    dates.sort((a, b) => b.compareTo(a));
    final latest = DateTime(dates.first.year, dates.first.month, dates.first.day);
    final today = DateTime.now();
    final nowDay = DateTime(today.year, today.month, today.day);
    final diff = nowDay.difference(latest).inDays;
    if (diff == 0) return 'сегодня';
    if (diff == 1) return 'вчера';
    return '${diff.abs()} дн. назад';
  }

  String _overviewDateLabel(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Сегодня\n${DateFormat('HH:mm').format(date)}';
    if (diff == 1) return 'Вчера\n${DateFormat('HH:mm').format(date)}';
    return DateFormat('d MMM\nHH:mm', 'ru').format(date).replaceAll('.', '');
  }

  String _formatOverviewDate(String raw) {
    if (raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T')) ?? _tryParseRuDate(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  String _appendUnit(String value, String unit) {
    final lower = value.toLowerCase();
    if (lower.contains(unit.toLowerCase())) return value;
    return '$value $unit';
  }

  double? _parseOverviewNumber(dynamic value) {
    final raw = _asStr(value).replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  Widget _buildGeneralDetailsActionsPane() {
    final photo = _normalizeImage(widget.player['photo']);
    final name = _cmrFullName();
    final position = _firstNotEmpty([widget.player['position'], widget.player['player_position']]);
    final number = _firstNotEmpty([widget.player['jersey_number'], widget.player['number'], widget.player['player_number']]);
    final age = _playerAge();
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']]) : _playerClub();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(26)),
          child: Row(
            children: [
              Stack(
                children: [
                  _buildPhotoPreviewTap(
                    imageUrl: photo,
                    child: _buildCircleNetworkImage(
                      imageUrl: photo,
                      size: 76,
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                      fallback: const Icon(Icons.person_rounded, color: _AppColors.cmrGreen),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AppColors.textPrimary, fontSize: 17.2, fontWeight: FontWeight.w700, height: 1.08)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _buildTrainerLikePill(position.isEmpty ? 'Амплуа не указано' : position, Icons.sports_soccer_rounded, _AppColors.cmrGreen),
                        _buildTrainerLikePill(number.isEmpty ? 'Номер не указан' : '№ $number', Icons.tag_rounded, _AppColors.textSecondary),
                        _buildTrainerLikePill(age.isEmpty ? 'Возраст —' : '$age лет', Icons.cake_rounded, _AppColors.textSecondary),
                        if (team.isNotEmpty) _buildTrainerLikePill(team, Icons.groups_2_rounded, _AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPlayerModalAction(icon: Icons.chat_bubble_rounded, label: 'Сообщение', color: _AppColors.cmrGreen, onTap: _openPrivateChat)),
            const SizedBox(width: 8),
            Expanded(child: _buildPlayerModalAction(icon: Icons.edit_rounded, label: 'Рабочая карточка', color: _AppColors.blue, onTap: _openPlayerEditorPanel)),
            const SizedBox(width: 8),
            Expanded(child: _buildPlayerModalAction(icon: Icons.fitness_center_rounded, label: 'Тренировка', color: _AppColors.orange, onTap: _assignTraining)),
          ],
        ),
        const SizedBox(height: 12),
        _buildStyledSectionCard(title: 'Связь', icon: Icons.chat_bubble_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildContactsContent(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Row(children: const [
              Icon(Icons.info_outline_rounded, color: _AppColors.cmrGreen, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Кнопка «Сообщение» сверху откроет личный чат с игроком.', style: TextStyle(color: _AppColors.textSecondary, fontSize: 11.7, fontWeight: FontWeight.w600, height: 1.35))),
            ]),
          ),
        ])),
        const SizedBox(height: 12),
        _buildStyledSectionCard(title: 'Спортивные данные', icon: Icons.sports_soccer_rounded, child: _buildSportDataContent()),
      ],
    );
  }


  Widget _buildPlayerModalAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10.7, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeutralInfoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF667085), fontSize: 10.6, fontWeight: FontWeight.w700)),
    );
  }


  Widget _buildContactsContent() {
    final email = _firstNotEmpty([widget.player['email'], widget.player['player_email'], widget.player['user_email']]);
    final phone = _firstNotEmpty([widget.player['phone'], widget.player['player_phone'], widget.player['parent_phone']]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Email', email.isEmpty ? '—' : email),
        _buildInfoRow('Телефон', phone.isEmpty ? '—' : phone),
      ],
    );
  }

  Widget _buildSportDataContent() {
    final raw = _firstNotEmpty([widget.player['sport_data'], widget.player['sports_data'], widget.player['metrics']]);
    final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) {
      return Text('Спортивные данные пока не заполнены.', style: _bodyStyle(size: 12.5, color: const Color(0xFF667085), weight: FontWeight.w700));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.take(6).map((line) {
        final parts = line.split(':');
        final label = parts.first.trim();
        final value = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
        return _buildInfoRow(label.isEmpty ? 'Показатель' : label, value.isEmpty ? '—' : value);
      }).toList(),
    );
  }

  Widget _buildGeneralCenterInfoPane() {
    final readiness = _profileReadinessPercent();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      children: [
        _buildProfileReadinessBadge(readiness),
        const SizedBox(height: 12),
        _buildMainInfoSection(),
        const SizedBox(height: 12),
        _buildClubInfoSection(),
      ],
    );
  }

  Widget _buildCmrGuidePane(_CategoryTab tab) {
    final accent = _cmrTabAccent(tab.index);
    final steps = _cmrGuideSteps(tab.index);

    if (_cmrGuideCollapsed) {
      return Align(
        alignment: Alignment.topCenter,
        child: Tooltip(
          message: 'Открыть помощь',
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _cmrGuideCollapsed = false),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 176),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _cmrTabSoft(tab.index),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.question_mark_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(height: 10),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'Помощь',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: const Color(0xFF101828),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(Icons.keyboard_arrow_right_rounded, color: accent, size: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.help_outline_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Помощь: «${tab.title}»',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF101828), fontSize: _adaptiveFont(context, mobile: 18, wide: 19.2), fontWeight: FontWeight.w700, height: 1.1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Подсказки можно свернуть. Все данные, цифры, редакторы и кнопки действий находятся справа.',
                          style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF667085), fontSize: _adaptiveFont(context, mobile: 12.5, wide: 13.2), height: 1.35, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Свернуть помощь',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _cmrGuideCollapsed = true),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.keyboard_arrow_left_rounded, color: Color(0xFF667085), size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...List.generate(steps.length, (i) {
                final s = steps[i];
                return _buildCmrGuideStep(number: i + 1, title: s['title']!, text: s['text']!, accent: accent);
              }),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _cmrGuideSteps(int index) {
    switch (index) {
      case 1:
        return const [
          {'title': 'Где добавлять', 'text': 'Кнопки добавления и редактирования метрик находятся справа. Центральный блок не повторяет эти действия.'},
          {'title': 'Что вносить', 'text': 'Добавляйте рост, вес, скорость, выносливость, игровые показатели и любые контрольные значения тренера.'},
          {'title': 'Как вести динамику', 'text': 'Обновляйте значения после тестов, матчей и тренировочных циклов, чтобы видеть прогресс игрока.'},
        ];
      case 2:
        return const [
          {'title': 'Достижения', 'text': 'Справа добавляйте турниры, награды, места, грамоты и важные спортивные события игрока.'},
          {'title': 'Медиа', 'text': 'Прикрепляйте фото или ссылки к достижениям, чтобы портфолио выглядело как полноценная карточка игрока.'},
          {'title': 'Порядок', 'text': 'Сначала внесите название и дату, затем добавьте описание и материалы.'},
        ];
      case 3:
        return const [
          {'title': 'Медкарта', 'text': 'Справа создаются записи: осмотры, травмы, восстановление, ограничения, документы и рекомендации.'},
          {'title': 'Файлы', 'text': 'Прикрепляйте фото, PDF или документ врача, чтобы тренер видел основание для ограничения нагрузки.'},
          {'title': 'Контроль', 'text': 'Проверяйте медкарту перед матчами и интенсивными тренировками.'},
        ];
      case 4:
        return const [
          {'title': 'Календарь', 'text': 'Даты с командными тренировками подсвечиваются. Нажмите дату, чтобы отфильтровать список.'},
          {'title': 'Только тренировки', 'text': 'Журнал посещаемости, самооценка, оценка тренера и личные задания вынесены из календаря тренировок.'},
          {'title': 'Детали', 'text': 'На широком экране выбранная тренировка открывается справа без лишнего модального окна.'},
        ];
      case 54:
        return const [
          {'title': 'Назначенные тренировки', 'text': 'Здесь собраны личные тренировки и индивидуальные задания игрока.'},
          {'title': 'Поиск', 'text': 'Используйте строку поиска, чтобы быстро найти нужное назначение по названию, типу или месту.'},
          {'title': 'Назначить', 'text': 'Кнопка назначения осталась сверху, чтобы тренер мог быстро добавить новую личную тренировку.'},
        ];
      case 5:
        return const [
          {'title': 'Таблица матчей', 'text': 'Матчи справа представлены строками: дата, соперник, счёт, турнир, видео и ТТД.'},
          {'title': 'Календарь матчей', 'text': 'Разверните календарь и выберите дату — список сразу станет короче.'},
          {'title': 'Анализ', 'text': 'По нажатию на строку можно перейти к подробностям, видео или ТТД матча.'},
        ];
      case 7:
        return const [
          {'title': 'История тестов', 'text': 'Данные берутся из CMR Testing по команде, возрастному этапу и дате.'},
          {'title': 'Календарь', 'text': 'Календарь тестирования свернут по умолчанию. Откройте его, чтобы выбрать дату.'},
          {'title': 'Таблица', 'text': 'Результаты игрока отображаются таблицей: тест, значение, единица и категория.'},
        ];
      case 8:
        return const [
          {'title': 'Экспорт', 'text': 'Перед выгрузкой проверьте заполненность профиля и актуальность разделов справа.'},
          {'title': 'PDF', 'text': 'Экспорт собирает профиль, метрики, медкарту, матчи, дневник и тестирование.'},
          {'title': 'Обновление', 'text': 'Если данных не хватает — обновите нужный раздел справа и повторите экспорт.'},
        ];
      default:
        return const [{'title': 'Рабочая зона', 'text': 'Выберите раздел слева, справа откроется рабочий редактор.'}];
    }
  }

  Widget _buildCmrGuideStep({
    required int number,
    required String title,
    required String text,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Center(child: Text('$number', style: TextStyle(color: accent, fontSize: 11.2, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _cmrTitleText(context, mobile: 13.5, wide: 15.0, color: const Color(0xFF101828))),
                const SizedBox(height: 4),
                Text(text, style: _cmrBodyText(context, mobile: 12.2, wide: 13.2, color: const Color(0xFF667085), weight: FontWeight.w700, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmrTopBar({required bool compact}) {
    final tab = _categoryTabs.firstWhere((e) => e.index == _selectedTabIndex, orElse: () => _categoryTabs.first);
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player["team_name"], widget.player["teamName"]]) : _playerClub();

    return Container(
      margin: EdgeInsets.fromLTRB(0, 12, compact ? 12 : 12, 8),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 10 : 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), ),
      child: Row(
        children: [
          _buildCmrSectionBadge(tab: tab),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tab.index == 0 ? 'Профиль игрока' : tab.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: compact ? 19 : 23, fontWeight: FontWeight.w700, color: _AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(team.isEmpty ? tab.subtitle : '$team • ${tab.subtitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textSecondary, fontSize: compact ? 12 : 13.4, fontWeight: FontWeight.w700)),
          ])),
          if (!compact) ...[
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.chat_bubble_rounded, label: 'Сообщение', onTap: _openPrivateChat),
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.edit_rounded, label: 'Редактировать', onTap: _openPlayerEditorPanel),
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.fitness_center_rounded, label: 'Тренировка', onTap: _assignTraining),
          ],
          const SizedBox(width: 10),
          _buildCmrIconButton(icon: _designLoading ? Icons.sync_rounded : Icons.refresh_rounded, onTap: _refreshCmrProfile),
        ],
      ),
    );
  }

  Widget _buildCmrSectionBadge({required _CategoryTab tab}) {
    final accent = _cmrTabAccent(tab.index);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(18)),
      child: Icon(tab.icon, color: accent, size: 22),
    );
  }

  Widget _buildCmrIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: _AppColors.primaryGreen),
      ),
    );
  }

  Widget _buildCmrHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final accent = _actionAccent(icon, label);
    return Material(
      color: accent.withOpacity(.09),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 21, color: accent),
            const SizedBox(width: 7),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 11.2, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCmrPlayerHero({required bool compact}) {
    final photo = _normalizeImage(widget.player["photo"]);
    final name = _cmrFullName();
    final position = _firstNotEmpty([widget.player["position"], widget.player["player_position"]]);
    final number = _firstNotEmpty([widget.player["jersey_number"], widget.player["number"], widget.player["player_number"]]);
    final age = _playerAge();
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player["team_name"], widget.player["teamName"]]) : _playerClub();
    final readiness = _profileReadinessPercent();

    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, compact ? 12 : 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(26)),
      child: Row(children: [
        Stack(children: [
          _buildPhotoPreviewTap(imageUrl: photo, child: _buildCircleNetworkImage(imageUrl: photo, size: 76, borderColor: Colors.transparent, borderWidth: 0, fallback: const Icon(Icons.person_rounded, color: _AppColors.cmrGreen))),
          Positioned(right: 0, bottom: 0, child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 15))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: compact ? 20 : 22, height: 1.08, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _buildTrainerLikePill(position.isEmpty ? 'Амплуа не указано' : position, Icons.sports_soccer_rounded, _AppColors.cmrGreen),
            _buildTrainerLikePill(number.isEmpty ? 'Номер не указан' : '№ $number', Icons.tag_rounded, _AppColors.textSecondary),
            _buildTrainerLikePill(age.isEmpty ? 'Возраст —' : '$age лет', Icons.cake_rounded, _AppColors.textSecondary),
            if (team.isNotEmpty) _buildTrainerLikePill(team, Icons.groups_2_rounded, _AppColors.textSecondary),
          ]),
        ])),
        if (!compact) ...[
          const SizedBox(width: 12),
          Container(width: 104, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(.82), borderRadius: BorderRadius.circular(22)), child: Column(children: [Text('$readiness%', style: const TextStyle(color: _AppColors.textPrimary, fontSize: 18.9, fontWeight: FontWeight.w700)), const Text('заполнено', style: TextStyle(color: _AppColors.textSecondary, fontSize: 10.6, fontWeight: FontWeight.w700))])),
        ],
      ]),
    );
  }

  Widget _buildCmrDarkChip(String text) {
    return _buildTrainerLikePill(text, Icons.circle_rounded, _AppColors.textSecondary);
  }


  Widget _buildCmrMobileHero({Key? key, required bool collapsed}) {
    final photo = _normalizeImage(widget.player["photo"]);
    final name = _cmrFullName();
    final position = _firstNotEmpty([widget.player["position"], widget.player["player_position"]]);
    final number = _firstNotEmpty([widget.player["jersey_number"], widget.player["number"], widget.player["player_number"]]);
    final age = _playerAge();
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player["team_name"], widget.player["teamName"]]) : _playerClub();
    final avatarSize = collapsed ? 40.0 : 58.0;
    final titleSize = collapsed ? 14.5 : 17.2;
    final meta = [if (position.isNotEmpty) position, if (number.isNotEmpty) '№ $number', if (!collapsed && age.isNotEmpty) '$age лет', if (!collapsed && team.isNotEmpty) team].join(' • ');
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      padding: EdgeInsets.all(collapsed ? 10 : 14),
      decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(collapsed ? 20 : 26)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Stack(children: [
          _buildPhotoPreviewTap(imageUrl: photo, child: _buildCircleNetworkImage(imageUrl: photo, size: avatarSize, borderColor: Colors.transparent, borderWidth: 0, fallback: const Icon(Icons.person_rounded, color: _AppColors.cmrGreen))),
          if (!collapsed) Positioned(right: 0, bottom: 0, child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 14))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: collapsed ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: _AppColors.textPrimary, fontSize: titleSize, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -.2)),
          SizedBox(height: collapsed ? 3 : 6),
          Text(meta.isEmpty ? 'Амплуа не указано' : meta, maxLines: collapsed ? 1 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AppColors.textSecondary, fontSize: 10.5, height: 1.25, fontWeight: FontWeight.w600)),
          if (!collapsed) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildCmrMobileAction(icon: Icons.chat_bubble_rounded, label: 'Сообщение', onTap: _openPrivateChat)),
              const SizedBox(width: 8),
              Expanded(child: _buildCmrMobileAction(icon: Icons.edit_rounded, label: 'Редактировать', onTap: _openPlayerEditorPanel)),
              const SizedBox(width: 8),
              Expanded(child: _buildCmrMobileAction(icon: Icons.fitness_center_rounded, label: 'Тренировка', onTap: _assignTraining)),
            ]),
          ],
        ])),
      ]),
    );
  }


  Widget _buildCmrMobileAction({required IconData icon, required String label, required VoidCallback onTap}) {
    final accent = _actionAccent(icon, label);
    return Material(
      color: accent.withOpacity(.09),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 21, color: accent),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 10.7, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCmrMobileActiveHint() {
    final tab = _categoryTabs.firstWhere((e) => e.index == _selectedTabIndex, orElse: () => _categoryTabs.first);
    final accent = _cmrTabAccent(tab.index);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(11)), child: Icon(tab.icon, size: 16, color: accent)),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Раздел открыт ниже', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AppColors.textPrimary, fontSize: 11.7, fontWeight: FontWeight.w700, height: 1.1)),
          SizedBox(height: 2),
          Text('Листайте экран, чтобы смотреть данные.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _AppColors.textSecondary, fontSize: 10.4, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _buildCmrMobileBottomMenu() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BottomNavigationBar(
            currentIndex: _cmrMobileBottomIndex(),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: _AppColors.primaryGreen,
            unselectedItemColor: _AppColors.textSecondary,
            selectedFontSize: 10.8,
            unselectedFontSize: 10.2,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            onTap: _handleCmrMobileBottomTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Обзор'),
              BottomNavigationBarItem(icon: Icon(Icons.sports_soccer_rounded), label: 'Матчи'),
              BottomNavigationBarItem(icon: Icon(Icons.terrain_rounded), label: 'Тренировки'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'Тесты'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'Ещё'),
            ],
          ),
        ),
      ),
    );
  }


  int _cmrMobileBottomIndex() {
    switch (_selectedTabIndex) {
      case 0:
        return 0;
      case 5:
        return 1;
      case 4:
        return 2;
      case 7:
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _handleCmrMobileBottomTap(int index) async {
    final direct = <int, int>{0: 0, 1: 5, 2: 4, 3: 7};
    if (direct.containsKey(index)) {
      final tabIndex = direct[index]!;
      if (tabIndex == 0) {
        if (mounted) setState(() => _selectedTabIndex = 0);
        return;
      }
      final tab = _categoryTabs.firstWhere((t) => t.index == tabIndex);
      await _openCmrMobileTabSheet(tab);
      return;
    }

    await _openCmrMobileMoreSheet();
  }

  Future<void> _openCmrMobileMoreSheet() async {
    _CategoryTab tabByIndex(int index) => _categoryTabs.firstWhere((t) => t.index == index);
    final items = <_PlayerMobileMoreSheetItem>[
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(50), accent: _AppColors.cmrGreen),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(1), accent: _AppColors.cmrGreen),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(51), accent: _AppColors.blue),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(52), accent: _AppColors.cmrGreen),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(54), accent: _AppColors.blue),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(2), accent: _AppColors.orange),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(3), accent: _AppColors.cmrGreen),
      _PlayerMobileMoreSheetItem.fromTab(tabByIndex(8), accent: _AppColors.blue),
      const _PlayerMobileMoreSheetItem(
        index: -1,
        icon: Icons.edit_outlined,
        title: 'Редактировать',
        subtitle: 'Изменить данные игрока',
        accent: _AppColors.blue,
      ),
    ];

    final playerName = _firstNotEmpty([
      widget.player['fullName'],
      widget.player['full_name'],
      widget.player['name'],
    ]);
    final teamName = _playerClub().isEmpty
        ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']])
        : _playerClub();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final h = MediaQuery.of(sheetContext).size.height;
        final bottom = MediaQuery.of(sheetContext).padding.bottom;

        return Container(
          constraints: BoxConstraints(maxHeight: h * .90),
          margin: EdgeInsets.zero,
          padding: EdgeInsets.fromLTRB(8, 8, 8, 10 + bottom),
          decoration: BoxDecoration(
            color: _AppColors.background,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              _buildPlayerMobileMoreHeaderCard(
                playerName: playerName.isEmpty ? 'Карточка игрока' : playerName,
                teamName: teamName,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Разделы',
                              style: TextStyle(
                                color: _AppColors.textPrimary,
                                fontSize: 13.8,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _AppColors.primaryGreen.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${items.length}',
                              style: const TextStyle(
                                color: _AppColors.primaryGreen,
                                fontSize: 10.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = item.index >= 0 && item.index == _selectedTabIndex;
                            return _buildWorkspaceMobileMoreTile(
                              item: item,
                              active: active,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                if (item.index == -1) {
                                  _openPlayerEditorPanel();
                                  return;
                                }
                                final tab = _categoryTabs.firstWhere((t) => t.index == item.index);
                                _openCmrMobileTabSheet(tab);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerMobileMoreHeaderCard({
    required String playerName,
    required String teamName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 14.6,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teamName.trim().isEmpty ? 'Профиль игрока и разделы анализа' : 'Команда: $teamName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 11.2,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceMobileMoreTile({
    required _PlayerMobileMoreSheetItem item,
    required bool active,
    required VoidCallback onTap,
  }) {
    final titleColor = active ? item.accent : _AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? item.accent.withOpacity(.08) : _AppColors.cmrSoftPanel,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _AppColors.softFor(item.accent),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon, color: item.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 13.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.textSecondary,
                        fontSize: 11.2,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(active ? 1 : .72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: active ? item.accent : _AppColors.textSecondary,
                  size: active ? 18 : 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  VoidCallback? _mobileSheetFabAction(int tabIndex) => _sectionFabAction(tabIndex);

  IconData _mobileSheetFabIcon(int tabIndex) => _sectionFabIcon(tabIndex);

  String _mobileSheetFabLabel(int tabIndex) {
    switch (tabIndex) {
      case 1:
      case 51:
        return 'Метрика';
      case 2:
        return 'Достижение';
      case 3:
        return 'Запись';
      case 4:
      case 54:
        return 'Тренировка';
      default:
        return 'Добавить';
    }
  }


  Future<void> _handleCmrSidebarTabTap(_CategoryTab tab) async {
    await _selectCmrTab(tab.index);
  }

  

  VoidCallback? _sectionFabAction(int tabIndex) {
    switch (tabIndex) {
      case 1:
      case 51:
        return _showEditMetricsDialog;
      case 2:
        return _showEditAchievementsDialog;
      case 3:
        return _showAddMedicalRecordDialog;
      case 4:
      case 54:
        return _assignTraining;
      default:
        return null;
    }
  }

  IconData _sectionFabIcon(int tabIndex) {
    switch (tabIndex) {
      case 1:
      case 51:
        return Icons.add_chart_rounded;
      case 2:
        return Icons.emoji_events_rounded;
      case 3:
        return Icons.add_rounded;
      case 4:
      case 54:
        return Icons.add_task_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  String _sectionFabLabel(int tabIndex) {
    switch (tabIndex) {
      case 1:
      case 51:
        return 'Добавить метрику';
      case 2:
        return 'Добавить достижение';
      case 3:
        return 'Добавить запись';
      case 4:
      case 54:
        return 'Назначить тренировку';
      default:
        return 'Добавить';
    }
  }

  Future<void> _openCmrTabletTabSheet(_CategoryTab tab) async {
    if (!mounted) return;

    if ((tab.index == 4 || tab.index == 52 || tab.index == 54) && !eventsLoading && teamEvents.isEmpty) {
      await _loadTrainingSectionData(force: true);
      if (attendanceLog.isEmpty && !attendanceLoading) {
        await _loadAttendanceLog(force: false);
      }
    }
    if (tab.index == 7 && playerTestingSessions.isEmpty && !playerTestingLoading) {
      await _loadPlayerTestingHistory(force: false);
    }
    if ((tab.index == 5 || tab.index == 50) && matches.isEmpty && !matchesLoading) {
      await _loadMatches(force: false);
    }

    // Важно: не переключаем основной экран на выбранный раздел.
    // Фон остаётся страницей «Общие», а раздел открывается только в CMR-окне.
    final accent = _cmrTabAccent(tab.index);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.28),
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final dialogWidth = size.width >= 1280 ? 1180.0 : size.width * .94;
        final dialogHeight = size.height >= 860 ? 790.0 : size.height * .90;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6F8FA),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _cmrTabSoft(tab.index),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(tab.icon, color: accent, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tab.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF101828),
                                      fontSize: 18.9,
                                      fontWeight: FontWeight.w700,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    tab.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: const Color(0xFF667085),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StatefulBuilder(
                          builder: (context, modalSetState) {
                            _activeSectionSheetSetState = modalSetState;
                            return _buildTabContentByIndex(tab.index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeSectionSheetSetState = null;

    if (mounted && MediaQuery.of(context).size.width >= 720) {
      setState(() => _selectedTabIndex = 0);
    }
  }

  Future<void> _openCmrMobileTabSheet(_CategoryTab tab) async {
    if (!mounted) return;

    if ((tab.index == 4 || tab.index == 52 || tab.index == 54) && !eventsLoading && teamEvents.isEmpty) {
      await _loadTrainingSectionData(force: true);
      if (attendanceLog.isEmpty && !attendanceLoading) {
        await _loadAttendanceLog(force: false);
      }
    }
    if (tab.index == 7 && playerTestingSessions.isEmpty && !playerTestingLoading) {
      await _loadPlayerTestingHistory(force: false);
    }
    if ((tab.index == 5 || tab.index == 50) && matches.isEmpty && !matchesLoading) {
      await _loadMatches(force: false);
    }

    // Основной экран остаётся на «Общие», раздел показываем только в нижнем окне.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          widthFactor: 1,
          heightFactor: .97,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _AppColors.cmrBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _cmrTabSoft(tab.index),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(tab.icon, color: _cmrTabAccent(tab.index), size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tab.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF101828), fontSize: 13.8, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tab.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF667085), fontSize: 11.2, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFF667085),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, modalSetState) {
                        _activeSectionSheetSetState = modalSetState;
                        return _buildTabContentByIndex(tab.index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    _activeSectionSheetSetState = null;

    if (mounted && MediaQuery.of(context).size.width < 720) {
      setState(() => _selectedTabIndex = 0);
    }
  }

  bool _onCmrMobileScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final shouldCollapse = notification.metrics.pixels > 54;
    if (shouldCollapse != _mobileHeroCollapsed && mounted) {
      setState(() => _mobileHeroCollapsed = shouldCollapse);
    }
    return false;
  }

  _CategoryTab _currentCmrTab() {
    return _categoryTabs.firstWhere(
      (e) => e.index == _selectedTabIndex,
      orElse: () => _categoryTabs.first,
    );
  }

  Widget _buildPlayerProfileMinimizedWindow({required bool compact, required bool embedded}) {
    final name = _cmrFullName().isEmpty ? 'Профиль игрока' : _cmrFullName();
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: !embedded,
        bottom: !embedded,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Container(
              height: 58,
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EDF2), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 24, offset: const Offset(0, 12))],
              ),
              child: Row(
                children: [
                  _buildCmrWindowRoundControl(
                    icon: Icons.keyboard_arrow_up_rounded,
                    tooltip: 'Развернуть профиль',
                    onTap: () => setState(() => _playerProfileWindowMinimized = false),
                  ),
                  const SizedBox(width: 10),
                  _buildSmallRoundIcon(Icons.person_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF101828), fontSize: 14, fontWeight: FontWeight.w800, height: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrPcWindow({required bool compact, required bool embedded}) {
    if (_playerProfileWindowMinimized) {
      return _buildPlayerProfileMinimizedWindow(compact: compact, embedded: embedded);
    }

    final media = MediaQuery.of(context);
    // Встроенный профиль оставляем как аккуратное CMR-окно с отступами и радиусом,
    // по аналогии с Tracker/Teams, а не растягиваем в край без формы.
    final fullWindow = _playerProfileWindowMaximized;
    final windowPadding = fullWindow
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14);

    return Material(
      color: const Color(0xFFF6F7F9),
      child: SafeArea(
        top: !embedded && !fullWindow,
        bottom: !embedded && !fullWindow,
        child: Padding(
          padding: windowPadding,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(fullWindow ? 16 : 24),
              border: Border.all(color: const Color(0xFFE8EDF2), width: 1),
              boxShadow: fullWindow
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(.045),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    _buildCmrShellSidebar(compact: compact),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE8EDF2)),
                    Expanded(
                      child: MediaQuery(
                        data: media.copyWith(textScaleFactor: compact ? 0.82 : 0.84),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14),
                          child: _buildCmrTabletWorkspace(compact: compact),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrPcWindowHeader({required bool compact}) {
    final photo = _normalizeImage(widget.player['photo']);
    final name = _cmrFullName();
    final tab = _currentCmrTab();
    final team = _playerClub().isEmpty
        ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']])
        : _playerClub();
    final position = _firstNotEmpty([widget.player['position'], widget.player['player_position'], widget.player['role']]);
    final number = _firstNotEmpty([widget.player['jersey_number'], widget.player['number'], widget.player['player_number']]);
    final age = _playerAge();
    final meta = [
      if (position.trim().isNotEmpty) position,
      if (number.trim().isNotEmpty) '№ $number',
      if (age.trim().isNotEmpty) '$age лет',
      if (team.trim().isNotEmpty) team,
    ].join(' · ');

    return Container(
      height: compact ? 62 : 68,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 8, compact ? 12 : 14, 8),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          _buildCmrWindowTrafficLights(),
          SizedBox(width: compact ? 10 : 14),
          _buildCmrWindowPlayerAvatar(photo: photo, size: compact ? 40 : 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'Профиль игрока' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          color: const Color(0xFF101828),
                          fontSize: compact ? 14.0 : 15.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.2,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: _AppColors.cmrGreen, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  meta.isEmpty ? tab.subtitle : '$meta · ${tab.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    color: const Color(0xFF667085),
                    fontSize: compact ? 9.5 : 10.2,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            _buildCmrWindowAction(icon: Icons.chat_bubble_outline_rounded, label: 'Сообщение', onTap: _openPrivateChat),
            const SizedBox(width: 8),
            _buildCmrWindowAction(icon: Icons.edit_outlined, label: 'Редактировать', onTap: _openPlayerEditorPanel),
            const SizedBox(width: 8),
            _buildCmrWindowAction(icon: Icons.fitness_center_rounded, label: 'Тренировка', onTap: _assignTraining),
          ],
          const SizedBox(width: 8),
          _buildCmrWindowIconButton(icon: _designLoading ? Icons.sync_rounded : Icons.refresh_rounded, onTap: _refreshCmrProfile, tooltip: 'Обновить'),
          const SizedBox(width: 8),
          _buildCmrWindowIconButton(icon: Icons.close_rounded, onTap: _closePlayerProfileScreen, tooltip: 'Закрыть'),
        ],
      ),
    );
  }

  Widget _buildCmrWindowTrafficLights() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCmrWindowRoundControl(icon: Icons.close_rounded, tooltip: 'На главный экран', onTap: _closePlayerProfileScreen),
        const SizedBox(width: 7),
        _buildCmrWindowRoundControl(
          icon: Icons.remove_rounded,
          tooltip: 'Свернуть профиль',
          onTap: () => setState(() => _playerProfileWindowMinimized = true),
        ),
        const SizedBox(width: 7),
        _buildCmrWindowRoundControl(
          icon: _playerProfileWindowMaximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
          tooltip: _playerProfileWindowMaximized ? 'Вернуть размер' : 'Развернуть профиль',
          onTap: () => setState(() => _playerProfileWindowMaximized = !_playerProfileWindowMaximized),
        ),
      ],
    );
  }

  Widget _buildCmrWindowPlayerAvatar({required String? photo, required double size}) {
    return _buildPhotoPreviewTap(
      imageUrl: photo,
      child: _buildCircleNetworkImage(
        imageUrl: photo,
        size: size,
        borderColor: Colors.transparent,
        borderWidth: 0,
        fallback: const Icon(Icons.person_rounded, color: _AppColors.cmrGreen),
      ),
    );
  }

  Widget _buildCmrWindowIconButton({required IconData icon, required VoidCallback onTap, required String tooltip}) {
    return _buildCmrWindowRoundControl(icon: icon, tooltip: tooltip, onTap: onTap, size: 40, iconSize: 19);
  }

  Widget _buildCmrWindowRoundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 34,
    double iconSize = 17,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: const Color(0xFF667085), size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrWindowAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF344054), size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  color: const Color(0xFF344054),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openPlayerFloatingCurrentTab() {
    final tab = _currentCmrTab();
    _openPlayerFloatingPane(
      pane: 'workspace',
      title: tab.title,
      icon: tab.icon,
    );
  }

  void _openPlayerFloatingDetails() {
    final tab = _currentCmrTab();
    _openPlayerFloatingPane(
      pane: 'details',
      title: '${tab.title}: детали',
      icon: tab.icon,
    );
  }

  void _openPlayerFloatingPane({required String pane, required String title, required IconData icon}) {
    if (!mounted) return;
    setState(() {
      _playerFloatingPane = pane;
      _playerFloatingTitle = title;
      _playerFloatingIcon = icon;
      _playerFloatingMinimized = false;
      _playerFloatingMaximized = false;
      _playerFloatingOffset = null;
    });
  }

  void _closePlayerFloatingPane() {
    if (!mounted) return;
    setState(() {
      _playerFloatingPane = null;
      _playerFloatingMinimized = false;
      _playerFloatingMaximized = false;
      _playerFloatingOffset = null;
    });
  }

  Widget _buildPlayerFloatingContent() {
    final tab = _currentCmrTab();
    if (_playerFloatingPane == 'details') {
      return _buildCmrSelectionDetailsPane(tab);
    }
    return _buildCmrWorkspaceContent(tab: tab, compact: false);
  }

  Widget _buildPlayerWindowExpandDockButton({required bool compact}) {
    return const SizedBox.shrink();
  }


  Widget _buildPlayerFloatingWindowLayer({required bool compact}) {
    return const SizedBox.shrink();
  }


  Widget _buildSmallRoundIcon(IconData icon, {bool active = false}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF2F7F4) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 17, color: active ? _AppColors.cmrGreen : const Color(0xFF667085)),
    );
  }

  Widget _buildCmrPcTopTabs({required bool compact}) {
    return Container(
      height: compact ? 42 : 46,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 4, compact ? 10 : 14, 6),
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categoryTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final tab = _categoryTabs[index];
          final active = tab.index == _selectedTabIndex;
          return _CmrPcTopTabButton(
            tab: tab,
            active: active,
            compact: compact,
            fontFamily: _fontFamily,
            onTap: () => _selectCmrTab(tab.index),
          );
        },
      ),
    );
  }

  Widget _buildCmrEmbeddedTopTabs({required bool compact}) {
    return _buildCmrPcTopTabs(compact: compact);
  }

  Widget _buildEmbeddedWorkspaceBody({required bool compact}) {
    return _buildCmrPcWindow(compact: compact, embedded: true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;
    final compact = width < 1080;

    if (isTablet) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildCmrPcWindow(compact: compact, embedded: widget.embeddedInWorkspace),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _buildCmrMobileHero(
                key: ValueKey(_mobileHeroCollapsed),
                collapsed: _mobileHeroCollapsed,
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onCmrMobileScroll,
                child: RefreshIndicator(
                  color: const Color(0xFF178A45),
                  onRefresh: _refreshCmrProfile,
                  child: _buildGeneralTab(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCmrMobileBottomMenu(),
    );
  }



}


class _OverviewLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool fill;

  const _OverviewLinePainter({
    required this.values,
    required this.color,
    this.fill = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final range = (maxValue - minValue).abs() < .001 ? 1.0 : maxValue - minValue;
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width : (size.width / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 6)) - 3;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..color = color.withOpacity(.08)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(points.last, 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OverviewLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color || oldDelegate.fill != fill;
  }
}

class _OverviewTrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _OverviewTrendPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final safeValues = values.isEmpty ? const [5.5, 6.0, 6.4, 6.2, 6.8, 7.1, 7.0, 7.4] : values;
    final points = <Offset>[];
    for (var i = 0; i < safeValues.length; i++) {
      final x = safeValues.length == 1 ? size.width : (size.width / (safeValues.length - 1)) * i;
      final normalized = safeValues[i].clamp(0, 10).toDouble() / 10.0;
      final y = size.height - normalized * (size.height - 12) - 6;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withOpacity(.07));

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas.drawCircle(point, 3.6, dotFill);
      canvas.drawCircle(point, 3.6, dotStroke);
    }

    final last = points.last;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(math.max(0.0, last.dx - 18), math.max(0.0, last.dy - 31), 36, 24),
      const Radius.circular(8),
    );
    canvas.drawRRect(badgeRect, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(text: safeValues.last.toStringAsFixed(1).replaceAll('.', ','), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 34);
    tp.paint(canvas, Offset(badgeRect.outerRect.left + (36 - tp.width) / 2, badgeRect.outerRect.top + (24 - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _OverviewTrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}


class _CmrEmbeddedPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;

  const _CmrEmbeddedPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width < 720 ? 28 : 34),
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              color: _AppColors.cmrSoftPanel,
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _AppColors.cmrSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: _AppColors.cmrGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AppColors.textPrimary, fontSize: 13.8, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _AppColors.textSecondary, fontSize: 11.2, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), color: _AppColors.textSecondary),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _CmrPlayerInlineEditor extends StatefulWidget {
  final Map<String, dynamic> player;
  final Future<void> Function(Map<String, String> fields) onSave;
  final VoidCallback onSaved;

  const _CmrPlayerInlineEditor({
    required this.player,
    required this.onSave,
    required this.onSaved,
  });

  @override
  State<_CmrPlayerInlineEditor> createState() => _CmrPlayerInlineEditorState();
}

class _CmrPlayerInlineEditorState extends State<_CmrPlayerInlineEditor> {
  late final TextEditingController firstNameC;
  late final TextEditingController lastNameC;
  late final TextEditingController birthC;
  late final TextEditingController citizenshipC;
  late final TextEditingController positionC;
  late final TextEditingController numberC;
  late final TextEditingController heightC;
  late final TextEditingController weightC;
  late final TextEditingController sportDataC;
  late final TextEditingController achievementsC;
  bool saving = false;

  String _s(dynamic v) => (v ?? '').toString();
  String _first(List<dynamic> values) {
    for (final v in values) {
      final text = _s(v).trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    final full = _first([p['fullName'], p['full_name'], p['name']]);
    final parts = full.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();
    firstNameC = TextEditingController(text: _first([p['first_name'], p['firstname'], parts.isNotEmpty ? parts.first : '']));
    lastNameC = TextEditingController(text: _first([p['last_name'], p['lastname'], parts.length > 1 ? parts.sublist(1).join(' ') : '']));
    birthC = TextEditingController(text: _first([p['birth_date'], p['birthday'], p['date_of_birth'], p['dob']]));
    citizenshipC = TextEditingController(text: _first([p['citizenship'], p['country'], p['nationality']]));
    positionC = TextEditingController(text: _first([p['position'], p['player_position']]));
    numberC = TextEditingController(text: _first([p['jersey_number'], p['number'], p['player_number']]));
    heightC = TextEditingController(text: _first([p['height'], p['player_height']]));
    weightC = TextEditingController(text: _first([p['weight'], p['player_weight']]));
    sportDataC = TextEditingController(text: _first([p['sport_data'], p['sports_data'], p['metrics']]));
    achievementsC = TextEditingController(text: _first([p['achievements'], p['achievement']]));
  }

  @override
  void dispose() {
    firstNameC.dispose();
    lastNameC.dispose();
    birthC.dispose();
    citizenshipC.dispose();
    positionC.dispose();
    numberC.dispose();
    heightC.dispose();
    weightC.dispose();
    sportDataC.dispose();
    achievementsC.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 11.7, fontWeight: FontWeight.w600),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, color: _AppColors.textSecondary, size: 19),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: _AppColors.textPrimary, fontSize: 12.6, fontWeight: FontWeight.w700),
      decoration: _dec(hint, icon),
    );
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final first = firstNameC.text.trim();
      final last = lastNameC.text.trim();
      final full = [first, last].where((e) => e.isNotEmpty).join(' ');
      await widget.onSave({
        'first_name': first,
        'last_name': last,
        'name': full,
        'full_name': full,
        'birth_date': birthC.text.trim(),
        'birthday': birthC.text.trim(),
        'citizenship': citizenshipC.text.trim(),
        'position': positionC.text.trim(),
        'jersey_number': numberC.text.trim(),
        'number': numberC.text.trim(),
        'height': heightC.text.trim(),
        'weight': weightC.text.trim(),
        'sport_data': sportDataC.text.trim(),
        'metrics': sportDataC.text.trim(),
        'achievements': achievementsC.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль игрока сохранён'), behavior: SnackBarBehavior.floating));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Основные данные', style: TextStyle(color: _AppColors.textPrimary, fontSize: 13.8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, c) {
                final two = c.maxWidth >= 560;
                final fields = [
                  _field(firstNameC, 'Имя', Icons.person_outline_rounded),
                  _field(lastNameC, 'Фамилия', Icons.person_outline_rounded),
                  _field(birthC, 'Дата рождения', Icons.calendar_today_rounded),
                  _field(citizenshipC, 'Гражданство', Icons.flag_outlined),
                  _field(positionC, 'Амплуа', Icons.sports_soccer_rounded),
                  _field(numberC, 'Номер', Icons.numbers_rounded),
                  _field(heightC, 'Рост', Icons.height_rounded),
                  _field(weightC, 'Вес', Icons.monitor_weight_outlined),
                ];
                if (!two) return Column(children: fields.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)).toList());
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: fields.map((w) => SizedBox(width: (c.maxWidth - 10) / 2, child: w)).toList(),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Спортивная карточка', style: TextStyle(color: _AppColors.textPrimary, fontSize: 13.8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _field(sportDataC, 'Метрики: рост, вес, голы, скорость…', Icons.query_stats_rounded, maxLines: 5),
              const SizedBox(height: 10),
              _field(achievementsC, 'Достижения игрока', Icons.emoji_events_outlined, maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(saving ? 'Сохранение...' : 'Сохранить изменения'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.cmrGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabletSectionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _TabletSectionActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF101828),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletFloatingSectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _TabletFloatingSectionAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101828),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileSectionFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _MobileSectionFab({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF101828),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.7,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CmrWindowDot extends StatelessWidget {
  final Color color;

  const _CmrWindowDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CmrPcTopTabButton extends StatefulWidget {
  final _CategoryTab tab;
  final bool active;
  final bool compact;
  final String? fontFamily;
  final VoidCallback onTap;

  const _CmrPcTopTabButton({
    required this.tab,
    required this.active,
    required this.compact,
    required this.fontFamily,
    required this.onTap,
  });

  @override
  State<_CmrPcTopTabButton> createState() => _CmrPcTopTabButtonState();
}

class _CmrPcTopTabButtonState extends State<_CmrPcTopTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? const Color(0xFFF2F7F4)
        : (_hovered ? const Color(0xFFF6F8FA) : Colors.transparent);
    final fg = active ? _AppColors.cmrGreen : const Color(0xFF475467);
    final iconColor = active ? _AppColors.cmrGreen : const Color(0xFF98A2B3);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: widget.compact ? 30 : 32,
            constraints: BoxConstraints(minWidth: widget.compact ? 36 : 68),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: active ? 6 : 4,
                  height: active ? 6 : 4,
                  decoration: BoxDecoration(
                    color: active ? _AppColors.cmrGreen : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 7),
                  Text(
                    widget.tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: widget.fontFamily,
                      color: fg,
                      fontSize: 9.8,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      height: 1,
                      letterSpacing: -.08,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  Icon(widget.tab.icon, color: iconColor, size: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTab {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryTab(this.index, this.title, this.subtitle, this.icon);
}


class _PlayerMobileMoreSheetItem {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _PlayerMobileMoreSheetItem({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  factory _PlayerMobileMoreSheetItem.fromTab(
    _CategoryTab tab, {
    required Color accent,
  }) {
    return _PlayerMobileMoreSheetItem(
      index: tab.index,
      icon: tab.icon,
      title: tab.title,
      subtitle: tab.subtitle,
      accent: accent,
    );
  }
}


class _SmallCardEditButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallCardEditButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _AppColors.cmrSoftPanel,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _AppColors.cmrGreen),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 10.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _CalendarCircleMarkerPainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;

  const _CalendarCircleMarkerPainter({
    required this.colors,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final safeColors = colors.isEmpty ? const [Color(0xFF64748B)] : colors;
    final fill = Paint()..style = PaintingStyle.fill;

    if (safeColors.length == 1) {
      fill.color = safeColors.first;
      canvas.drawOval(rect, fill);
    } else {
      final sweep = (math.pi * 2) / safeColors.length;
      var start = -math.pi / 2;

      for (final color in safeColors) {
        fill.color = color;
        canvas.drawArc(rect, start, sweep, true, fill);
        start += sweep;
      }
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borderColor;

    canvas.drawOval(rect.deflate(.75), border);
  }

  @override
  bool shouldRepaint(covariant _CalendarCircleMarkerPainter oldDelegate) {
    if (oldDelegate.borderColor != borderColor) return true;
    if (oldDelegate.colors.length != colors.length) return true;

    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i] != colors[i]) return true;
    }

    return false;
  }
}
class _ExportBadge extends StatelessWidget {
  final String label;
  const _ExportBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF178A45),
          fontSize: 10.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
