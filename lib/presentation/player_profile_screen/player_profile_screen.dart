import 'dart:convert';

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
import 'package:sportoteka/presentation/player_screen/player_match_detail_screen.dart';
import 'package:sportoteka/presentation/edit_player_screen/edit_player_screen.dart';

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
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF2FA86B);
  static const Color warning = Color(0xFFEA580C);
  static const Color info = Color(0xFF2563EB);
  static const Color white = Colors.white;
  static const Color surfaceLight = Colors.white;

  static const Color cmrDark = Color(0xFF0F172A);
  static const Color cmrGreen = Color(0xFF1F7A4D);
  static const Color cmrSoft = Color(0xFFF2F7F4);
  static const Color cmrBorder = Color(0xFFEAF0EC);
  static const Color cmrPanel = Colors.white;
  static const Color cmrSoftPanel = Color(0xFFF6F8FA);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF3E8FF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF1E8);
  static const Color teal = Color(0xFF0F766E);
  static const Color tealSoft = Color(0xFFE6F6F4);
  static const Color redSoft = Color(0xFFFEE2E2);

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == error) return redSoft;
    if (color == primaryGreen || color == cmrGreen || color == success) return cmrSoft;
    return surfaceLight;
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
      return error;
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
      fontFamily: 'default',
      headerRadius: 30,
      cardRadius: 28,
      avatarSize: 92,
      titleFontSize: 22,
      bodyFontSize: 14.5,
      primaryColorValue: 0xFF3FBF7F,
      secondaryColorValue: 0xFF2FA86B,
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

class PlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen>
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

  Color _actionAccent(IconData icon, String label) {
    final text = label.toLowerCase();

    if (text.contains('напис') || text.contains('чат') || icon == Icons.chat_bubble_outline_rounded) {
      return _AppColors.blue;
    }

    if (text.contains('трен') || text.contains('назнач') || icon == Icons.event_available_outlined || icon == Icons.add_task_rounded) {
      return _AppColors.orange;
    }

    if (text.contains('редакт') || text.contains('изм') || icon == Icons.edit_outlined || icon == Icons.edit_rounded) {
      return _AppColors.teal;
    }

    if (text.contains('мед') || text.contains('запись') || icon == Icons.medical_information_outlined || icon == Icons.health_and_safety_outlined) {
      return _AppColors.error;
    }

    if (text.contains('метрик') || icon == Icons.query_stats_rounded || icon == Icons.analytics_outlined || icon == Icons.show_chart_rounded) {
      return _AppColors.purple;
    }

    if (text.contains('достиж') || icon == Icons.emoji_events_outlined || icon == Icons.emoji_events_rounded) {
      return _AppColors.orange;
    }

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
  int _trainingSubTab = 0; // 0 события, 1 журнал, 2 индивидуальные

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

  void _rebuildOpenSectionSheet() {
    final updater = _activeSectionSheetSetState;
    if (updater == null) return;
    try {
      updater(() {});
    } catch (_) {
      _activeSectionSheetSetState = null;
    }
  }

  bool playerTestingLoading = false;
  String? playerTestingError;
  List<Map<String, dynamic>> playerTestingSessions = [];
  List<Map<String, dynamic>> playerTestingResults = [];


  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design
  _PlayerProfileDesign _design = _PlayerProfileDesign.defaults();
  bool _designLoading = false;
  bool _designSaving = false;
  int _trainerUserId = 0;

  final List<_CategoryTab> _categoryTabs = const [
    _CategoryTab(0, "Обзор", "Основная информация", Icons.person_outline_rounded),
    _CategoryTab(1, "Метрики", "Спортивные показатели", Icons.show_chart_rounded),
    _CategoryTab(2, "Достижения", "Награды и медиа", Icons.military_tech_rounded),
    _CategoryTab(3, "Медкарта", "Медицинские записи", Icons.medical_information_rounded),
    _CategoryTab(4, "Тренировки", "История и задания", Icons.sports_soccer_rounded),
    _CategoryTab(5, "Матчи", "Игровая история", Icons.table_chart_rounded),
    _CategoryTab(6, "Дневник", "Самооценка игрока", Icons.menu_book_rounded),
    _CategoryTab(7, "Тестирование", "История тестов", Icons.fact_check_rounded),
    _CategoryTab(8, "Экспорт", "PDF карточка игрока", Icons.picture_as_pdf_rounded),
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
    FontWeight weight = FontWeight.w900,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: size ?? _design.titleFontSize,
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
      fontSize: size ?? _design.bodyFontSize,
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
    double mobile = 18.0,
    double wide = 19.0,
    Color color = const Color(0xFF0F172A),
    FontWeight weight = FontWeight.w900,
  }) {
    return _titleStyle(
      size: _adaptiveFont(context, mobile: mobile, wide: wide),
      color: color,
      weight: weight,
    );
  }

  TextStyle _cmrSubtitleText(
    BuildContext context, {
    double mobile = 12.5,
    double wide = 13.6,
    Color color = const Color(0xFF64748B),
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
    double mobile = 12.0,
    double wide = 13.0,
    Color color = const Color(0xFF64748B),
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
      if (wide || _selectedTabIndex == 4) {
        _loadTrainingSectionData(force: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlayerProfileScreen oldWidget) {
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
              border: Border.all(color: Colors.grey.shade200),
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
            .split(',')
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
            .split(',')
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

    final direct = _asInt(widget.player["player_id"] ?? widget.player["id"]);
    if (direct > 0) {
      _resolvedPlayerId = direct;
      return _resolvedPlayerId;
    }

    final userId = _asInt(widget.player["user_id"]);
    if (userId <= 0) return 0;

    final pid = await PlayerIdResolver.resolvePlayerId(
      apiBase: _apiBase,
      userId: userId,
    );
    _resolvedPlayerId = pid;
    return _resolvedPlayerId;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        diaryLoading = false;
        diaryError = e.toString();
        diaryItems = [];
      });
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

  dynamic _firstRatingValue(Map<String, dynamic>? row, List<String> keys) {
    if (row == null) return null;
    for (final key in keys) {
      final v = row[key];
      if (v == null) continue;
      final s = _asStr(v).trim();
      if (s.isEmpty || s == "0" || s.toLowerCase() == "null") continue;
      return v;
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
    void put(String key, List<String> sourceKeys) {
      if (_asStr(target[key]).trim().isNotEmpty) return;
      for (final k in sourceKeys) {
        final v = source[k];
        if (_asStr(v).trim().isNotEmpty) {
          target[key] = v;
          return;
        }
      }
    }

    put("player_rating", const ["player_rating", "self_rating", "rating", "player_mark"]);
    put("coach_rating", const ["coach_rating", "trainer_rating", "coach_mark", "trainer_mark", "mark"]);
    put("coach_comment", const ["coach_comment", "trainer_comment", "comment"]);
    put("coach_note", const ["coach_note", "trainer_note", "note_coach"]);
    put("status", const ["status", "attendance_status", "presence_status"]);
    put("reason", const ["reason", "absence_reason"]);
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
      final hasUsefulAttendance = _attendanceStatusOf(ev) != "unset" ||
          _firstRatingValue(ev, const ["coach_rating", "trainer_rating", "coach_mark", "trainer_mark", "mark"]) != null ||
          _firstNotEmpty([ev["coach_comment"], ev["trainer_comment"], ev["comment"]]).isNotEmpty;
      if (!hasUsefulAttendance) continue;

      final merged = {
        ..._normalizeAttendanceRow(ev),
        ...?byEvent[id],
      };
      byEvent[id] = _normalizeAttendanceRow(merged);
    }

    final out = byEvent.values.toList();
    if (out.isEmpty && base.isNotEmpty) return base;
    return out;
  }

  List<Map<String, dynamic>> _trainingCalendarItems() {
    final out = <Map<String, dynamic>>[...teamEvents];
    for (final row in attendanceLog) {
      if (_parseEventDate(row) != null) out.add(row);
    }
    for (final row in calendarEvents) {
      final copy = Map<String, dynamic>.from(row);
      copy["date"] = _firstNotEmpty([
  copy["date"],
  copy["start_at"],
  copy["event_date"],
]);
      if (_parseEventDate(copy) != null) out.add(copy);
    }
    return out;
  }

  Future<void> _loadTrainingSectionData({bool force = false}) async {
    if (_teamId <= 0) return;

    await _loadTeamCalendar(force: force);
    await _loadPlayerTrainingHistory(force: force);

    if (_trainingSubTab == 1) {
      await _loadAttendanceLog(force: force);
    }
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
      // Важно: даже при выбранной дате загружаем весь месяц.
      // Иначе календарь внутри открытого профиля начинает показывать только записи выбранного дня.
      final monthBase = selectedDay ?? now;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        eventsLoading = false;
        eventsError = e.toString();
        teamEvents = [];
        selectedEvent = null;
        selectedEventPlayerInfo = null;
      });
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

  Future<void> _loadPlayerInfoForEvent(int eventId) async {
    setState(() => selectedEventPlayerInfo = null);
    _rebuildOpenSectionSheet();

    try {
      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final url = Uri.parse(
          "$_apiBase/get_player_event_info.php?event_id=$eventId&player_id=$playerId");
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = _decodeResponseMap(res.body);

      if (_isBadApiResponse(data)) {
        throw _apiErrorMessage(data, "Ошибка загрузки оценки");
      }

      final rawInfo = data["info"] ?? data["item"] ?? data["data"] ?? {};
      final info = rawInfo is Map
          ? Map<String, dynamic>.from(rawInfo)
          : <String, dynamic>{};

      _mergeEventFallbackInfo(info, selectedEvent);

      if (!mounted) return;
      setState(() => selectedEventPlayerInfo = info);
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
      // Важно: даже при выбранной дате загружаем весь месяц.
      // Иначе календарь внутри открытого профиля начинает показывать только записи выбранного дня.
      final monthBase = selectedDay ?? now;
      final from = DateTime(monthBase.year, monthBase.month, 1);
      final to = DateTime(monthBase.year, monthBase.month + 1, 1);

      final url = Uri.parse(
        "$_apiBase/get_player_attendance_log.php"
        "?team_id=$teamId"
        "&player_id=$playerId"
        "&from=${DateFormat('yyyy-MM-dd').format(from)}"
        "&to=${DateFormat('yyyy-MM-dd').format(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = _decodeResponseMap(res.body);

      if (_isBadApiResponse(data)) {
        throw _apiErrorMessage(data, "Ошибка загрузки посещений");
      }

      final dynamic rawItems = data["items"] ?? data["attendance"] ?? data["data"] ?? data["rows"] ?? [];

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
            "player_id": entry.key.toString(),
            ...value,
          });
        }).toList();
      }

      list = _mergeAttendanceWithTrainingHistory(list);

      list.sort((a, b) {
        final da = DateTime.tryParse(
              _asStr(a["date"] ?? a["start_at"] ?? a["day"])
                  .replaceAll(' ', 'T'),
            ) ??
            DateTime(1970);
        final db = DateTime.tryParse(
              _asStr(b["date"] ?? b["start_at"] ?? b["day"])
                  .replaceAll(' ', 'T'),
            ) ??
            DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        attendanceLog = list;
        attendanceLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attendanceLoading = false;
        attendanceError = e.toString();
        attendanceLog = [];
      });
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
                        style: TextStyle(fontWeight: FontWeight.w900)),
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
                color: const Color(0xFF111827).withOpacity(.78),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
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
      boxShadow: glow != null
          ? [
              BoxShadow(
                color: glow,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
      border: Border.all(
        color: borderColor ?? _primary,
        width: borderWidth,
      ),
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
      final from = _calendarFrom ?? DateTime(now.year, now.month, 1);
      final to = _calendarTo ?? DateTime(now.year, now.month + 1, 0);

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        calendarLoading = false;
        calendarError = e.toString();
        calendarEvents = [];
      });
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
      // Важно: используем тот же рабочий API, что и экран детального разбора матча
      // PlayerMatchDetailScreen. Он возвращает полный отчет по матчу, а здесь мы
      // фильтруем строки строго по текущему игроку.
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
  } catch (e) {
    if (!mounted) return;
    setState(() {
      matchesLoading = false;
      matchesError = e.toString();
      matches = [];
    });
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: myId,
            chatName: chatName,
          ),
        ),
      );
    } catch (e) {
      Get.snackbar("Чат", "Ошибка: $e",
          snackPosition: SnackPosition.BOTTOM);
    }
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
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
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
                    color: const Color(0xFF64748B),
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
                color: const Color(0xFF64748B),
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
          glow: const Color(0xFF0F172A).withOpacity(0.04),
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
              border: Border.all(color: _AppColors.cmrBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(showDetails ? 0.045 : 0.025),
                  blurRadius: showDetails ? 22 : 10,
                  offset: Offset(0, showDetails ? 10 : 3),
                ),
              ],
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _AppColors.cmrBorder)),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _AppColors.cmrBorder)),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _AppColors.cmrBorder)),
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
            border: Border.all(color: _AppColors.cmrBorder),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _AppColors.cmrBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF178A45)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 12.3, height: 1.05, fontWeight: FontWeight.w700, color: const Color(0xFF6B778A)))),
          ]),
          const SizedBox(height: 10),
          Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: isPosition ? 12.9 : 15.8, height: 1.05, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.2)),
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
            border: Border.all(color: accent.withOpacity(.18)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
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
                  border: Border.all(color: accent.withOpacity(.10)),
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
                        fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
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
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
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
                              fontSize: 22,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
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
                    border: Border.all(color: Colors.white.withOpacity(0.60)),
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
            border: Border.all(color: Colors.white.withOpacity(0.20)),
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
        border: Border.all(color: Colors.white.withOpacity(0.16)),
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
                fontSize: 11.2,
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                    fontSize: 10.5,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
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
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
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
            border: Border.all(color: _AppColors.cmrBorder),
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
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
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

                        if (tab.index == 6 && diaryItems.isEmpty && !diaryLoading) {
                          await _loadDiary();
                        }

                        if (tab.index == 4) {
                          await _loadTrainingSectionData(force: true);
                        }

                        if (tab.index == 5) await _loadMatches();

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
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(isActive ? 0.10 : 0.035),
                              blurRadius: isActive ? 14 : 10,
                              offset: Offset(0, isActive ? 5 : 3),
                            ),
                          ],
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
                                fontWeight: FontWeight.w900,
                                color: isActive ? Colors.white : const Color(0xFF0F172A),
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
        return _buildMetricsTab();
      case 2:
        return _buildAchievementsTab();
      case 3:
        return _buildMedicalTab();
      case 4:
        return _buildTrainingTab();
      case 5:
        return _buildMatchesTab();
      case 6:
        return _buildDiaryTab();
      case 7:
        return _buildTestingHistoryTab();
      case 8:
        return _buildExportTab();
      default:
        return _buildGeneralTab();
    }
  }

  

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IndexedStack(
        index: _selectedTabIndex,
        children: List.generate(
          _categoryTabs.length,
          (index) => _buildTabContentByIndex(index),
        ),
      ),
    );
  }

  // =============================
  // ОБЩИЕ
  // =============================
  Widget _buildGeneralTab() {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;

    final mainInfo = _buildMainInfoSection();
    final clubInfo = _design.showClubCard ? _buildClubInfoSection() : const SizedBox();
    final bioInfo = _design.showBioCard ? _buildBioInfoSection() : const SizedBox();

    if (isTablet) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          _buildCoachWorkspaceOverview(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 58,
                child: Column(
                  children: [
                    _buildCoachQuickActionsPanel(),
                    const SizedBox(height: 16),
                    _buildCoachFocusPanel(),
                    const SizedBox(height: 16),
                    _buildCoachDataReadinessPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 42,
                child: Column(
                  children: [
                    mainInfo,
                    const SizedBox(height: 16),
                    clubInfo,
                    if (_design.showBioCard) ...[
                      const SizedBox(height: 16),
                      bioInfo,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
      children: [
        _buildCoachWorkspaceOverview(),
        const SizedBox(height: 14),
        _buildCoachQuickActionsPanel(),
        const SizedBox(height: 14),
        _buildCoachFocusPanel(),
        const SizedBox(height: 14),
        _buildCoachDataReadinessPanel(),
        const SizedBox(height: 14),
        mainInfo,
        const SizedBox(height: 14),
        clubInfo,
        if (_design.showBioCard) ...[
          const SizedBox(height: 14),
          bioInfo,
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                          Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11, height: 1, color: const Color(0xFF667085), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(_displayValue(item.value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 15, height: 1.05, color: empty ? const Color(0xFF98A2B3) : const Color(0xFF101828), fontWeight: FontWeight.w800, letterSpacing: -0.15)),
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
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(0.018), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _AppColors.cmrSoft, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.tune_rounded, color: _AppColors.primaryGreen, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Основные характеристики', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 18, height: 1.05, fontWeight: FontWeight.w800, color: const Color(0xFF101828), letterSpacing: -0.25)),
                const SizedBox(height: 4),
                Text('Ключевые данные игрока без лишних вложенных рамок', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.5, height: 1.1, fontWeight: FontWeight.w600, color: const Color(0xFF667085))),
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
          border: Border.all(color: _AppColors.cmrBorder),
        ),
        child: Text(
          bio,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: _design.bodyFontSize,
            height: 1.48,
            color: const Color(0xFF111827),
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
                    Text(_displayValue(item.value), maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14.4, color: const Color(0xFF101828), weight: FontWeight.w800)),
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
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(0.018), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: accent, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 17, color: const Color(0xFF101828), weight: FontWeight.w800))),
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
        border: Border.all(color: _AppColors.cmrBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
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
                        color: const Color(0xFF64748B),
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
        border: Border.all(color: _AppColors.cmrBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$percent%', style: TextStyle(fontFamily: _fontFamily, fontSize: _adaptiveFont(context, mobile: 16, wide: 16.2), height: 1, fontWeight: FontWeight.w900, color: const Color(0xFF178A45))),
          const SizedBox(height: 4),
          Text('заполнено', style: TextStyle(fontFamily: _fontFamily, fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
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
        border: Border.all(color: _AppColors.cmrBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AppColors.cmrBorder)),
            child: Icon(icon, size: 18, color: const Color(0xFF178A45)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 12.5, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
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
          _buildCoachChecklistRow(Icons.menu_book_outlined, 'Дневник / самооценка', hasDiary ? 'Записей: ${diaryItems.length}' : 'Пока нет записей', hasDiary, () async { setState(() => _selectedTabIndex = 6); await _loadDiary(); }),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _AppColors.cmrBorder),
        boxShadow: [BoxShadow(color: const Color(0xFF111827).withOpacity(0.035), blurRadius: 22, offset: const Offset(0, 10))],
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
                  border: Border.all(color: _AppColors.cmrBorder),
                ),
                child: Icon(icon, size: 24, color: const Color(0xFF178A45)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 18, height: 1.05, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.25)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 12.5, height: 1.32, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
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
            border: Border.all(color: accent.withOpacity(.16)),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(.06), blurRadius: 14, offset: const Offset(0, 7)),
            ],
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
                      border: Border.all(color: accent.withOpacity(.10)),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.72),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withOpacity(.10)),
                    ),
                    child: Text(
                      _actionHint(title),
                      style: TextStyle(fontFamily: _fontFamily, fontSize: 9.5, fontWeight: FontWeight.w900, color: accent),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 14.2, height: 1.08, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.15)),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _AppColors.cmrBorder)),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _AppColors.cmrBorder)), child: Icon(icon, size: 21, color: const Color(0xFF178A45))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 14.2, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.1)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.8, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _AppColors.cmrBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, size: 20, color: const Color(0xFF178A45)), const Spacer(), const Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF94A3B8))]),
              const Spacer(),
              Text(value, style: TextStyle(fontFamily: _fontFamily, fontSize: 24, height: 1, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11.8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
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
  }) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    final sidePadding = isMobile ? 4.0 : 0.0;
    final accent = _AppColors.accentForIcon(icon);
    return ListView(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, isMobile ? 12 : 16),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(isMobile ? 22 : 26), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(0.018), blurRadius: 18, offset: const Offset(0, 8))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: isMobile ? 42 : 46, height: isMobile ? 42 : 46, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: accent, size: isMobile ? 20 : 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: isMobile ? 2 : 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 17.2, wide: 19.2, color: const Color(0xFF101828), weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: isMobile ? 3 : 2, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 12.1, wide: 13.4, color: const Color(0xFF667085), weight: FontWeight.w600)),
              ])),
            ]),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 520;
                return GridView.count(crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: wide ? 3.8 : 2.95, children: stats);
              }),
            ],
            if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 7, runSpacing: 7, children: actions)],
          ]),
        ),
        SizedBox(height: isMobile ? 10 : 14),
        ...children,
      ],
    );
  }


  Widget _buildCmrMiniStat(String title, String value, IconData icon) {
    final accent = _AppColors.accentForIcon(icon);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: _AppColors.softFor(accent), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 15, color: accent)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrTitleText(context, mobile: 13.0, wide: 15.0, color: const Color(0xFF101828), weight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _cmrSubtitleText(context, mobile: 9.4, wide: 11.2, color: const Color(0xFF667085), weight: FontWeight.w700)),
        ])),
      ]),
    );
  }


  Widget _buildCmrActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool compact = false,
  }) {
    final accent = _actionAccent(icon, label);
    final bg = primary ? accent : _AppColors.softFor(accent);
    final fg = primary ? Colors.white : const Color(0xFF101828);
    final iconColor = primary ? Colors.white : accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14, vertical: compact ? 8 : 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: accent.withOpacity(primary ? .13 : .035), blurRadius: primary ? 16 : 8, offset: Offset(0, primary ? 7 : 3))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: compact ? 26 : 28, height: compact ? 26 : 28, decoration: BoxDecoration(color: primary ? Colors.white.withOpacity(.16) : Colors.white.withOpacity(.82), shape: BoxShape.circle), child: Icon(icon, size: compact ? 15 : 16, color: iconColor)),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 11.5 : _adaptiveFont(context, mobile: 12.5, wide: 13.4), color: fg, weight: FontWeight.w800))),
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
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(isMobile ? 22 : 26), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(0.018), blurRadius: 16, offset: const Offset(0, 7))]),
      child: child,
    );
  }


  // =============================
  // МЕТРИКИ
  // =============================
  Widget _buildMetricsTab() {
    return _buildCmrSectionShell(
      title: 'Метрики игрока',
      subtitle: 'Быстрая оценка формы, физических данных и игровых показателей',
      icon: Icons.query_stats_rounded,
      stats: [
        _buildCmrMiniStat('Всего показателей', '${metrics.length}', Icons.analytics_outlined),
        _buildCmrMiniStat('Медкарта', '${medicalRecords.length}', Icons.health_and_safety_outlined),
        _buildCmrMiniStat('Тренировки', '${teamEvents.length}', Icons.fitness_center_rounded),
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_soccer_rounded),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_chart_rounded, label: 'Метрика', onTap: _showEditMetricsDialog),
        _buildCmrActionChip(icon: Icons.medical_information_outlined, label: 'Медкарта', onTap: () => setState(() => _selectedTabIndex = 3), compact: true),
      ],
      children: [
        if (metrics.isEmpty)
          _buildEmptyState(icon: Icons.analytics_outlined, message: 'Метрики пока не заполнены')
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 720;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 2 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: wide ? 3.8 : 3.25,
                ),
                itemBuilder: (_, i) => _buildMetricCard(metrics[i]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetricCard(String metric) {
    final parts = metric.split(':');
    final title = parts.isNotEmpty ? parts.first.trim() : 'Показатель';
    final value = parts.length > 1 ? parts.sublist(1).join(':').trim() : metric.trim();
    final lower = title.toLowerCase();
    final icon = lower.contains('скор')
        ? Icons.speed_rounded
        : lower.contains('рост')
            ? Icons.height_rounded
            : lower.contains('вес')
                ? Icons.monitor_weight_outlined
                : lower.contains('гол')
                    ? Icons.sports_soccer_rounded
                    : Icons.trending_up_rounded;

    return _buildCmrCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _AppColors.cmrBorder),
            ),
            child: Icon(icon, color: const Color(0xFF178A45), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(value.isEmpty ? 'Не указано' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 17, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
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
                Expanded(child: Text('Ключевые достижения', style: _titleStyle(size: 16, color: const Color(0xFF0F172A)))),
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
        onTap: () => launchUrl(Uri.parse(norm), mode: LaunchMode.externalApplication),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _AppColors.cmrBorder),
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
                  child: Text(isVideo ? 'Видео' : isImage ? 'Фото' : 'Файл', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w900, color: isImage ? Colors.white : const Color(0xFF178A45))),
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
      title: 'Медкарта игрока',
      subtitle: 'Осмотры, травмы, ограничения, документы и комментарии тренера',
      icon: Icons.medical_information_rounded,
      stats: [
        _buildCmrMiniStat('Всего записей', '${medicalRecords.length}', Icons.folder_copy_outlined),
        _buildCmrMiniStat('Осмотры', '$checks', Icons.health_and_safety_outlined),
        _buildCmrMiniStat('Травмы', '$injuries', Icons.healing_outlined),
        _buildCmrMiniStat('Вложения', '${medicalRecords.where((e) => _asStr(e['file_url']).isNotEmpty).length}', Icons.attach_file_rounded),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_rounded, label: 'Запись', onTap: _showAddMedicalRecordDialog),
      ],
      children: [
        if (medicalRecords.isEmpty)
          _buildEmptyState(icon: Icons.medical_services_rounded, message: 'Медицинских записей пока нет')
        else
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 760;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: medicalRecords.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 2 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: wide ? 1.72 : 1.28,
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

  Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
    final type = _asStr(record['type']).isEmpty ? 'Запись' : _asStr(record['type']);
    final title = _asStr(record['title']).isEmpty ? 'Без названия' : _asStr(record['title']);
    final value = _asStr(record['value']);
    final comment = _asStr(record['comment']);
    final date = _asStr(record['date']).isEmpty ? 'Не указана' : _asStr(record['date']);
    final fileUrl = _asStr(record['file_url']);

    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14), border: Border.all(color: _AppColors.cmrBorder)),
                child: Icon(type == 'Травма' ? Icons.healing_rounded : type == 'Осмотр' ? Icons.health_and_safety_rounded : Icons.medical_information_rounded, color: const Color(0xFF178A45), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.5, color: const Color(0xFF64748B), weight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 15.5, color: const Color(0xFF0F172A))),
                  ],
                ),
              ),
              _SmallCardEditButton(
                label: 'Изм.',
                icon: Icons.edit_rounded,
                onTap: () => _showEditMedicalRecordDialog(record),
              ),
            ],
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _AppColors.cmrBorder)), child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.5, color: const Color(0xFF334155), weight: FontWeight.w700))),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.comment_outlined, size: 15, color: Color(0xFF64748B)), const SizedBox(width: 6), Expanded(child: Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w600)))]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Expanded(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.5, color: const Color(0xFF64748B), weight: FontWeight.w800))),
              if (fileUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    final fullUrl = fileUrl.startsWith('http') ? fileUrl : '$_apiBase/../uploads/medical/$fileUrl';
                    launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.attach_file_rounded, size: 14),
                  label: const Text('Файл', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF178A45), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================
  // ТРЕНИРОВКИ
  // =============================
  Widget _buildTrainingTab() {
    return _buildCmrSectionShell(
      title: 'Тренировки',
      subtitle: 'История тренировок, посещаемость и индивидуальные задания игрока',
      icon: Icons.sports_soccer_rounded,
      stats: [
        _buildCmrMiniStat('Тренировки', '${teamEvents.length}', Icons.event_note_outlined),
        _buildCmrMiniStat('Журнал', '${attendanceLog.length}', Icons.fact_check_outlined),
        _buildCmrMiniStat('Личные', '${calendarEvents.length}', Icons.fitness_center_rounded),
        _buildCmrMiniStat('Даты', '${_markedDays(_trainingCalendarItems(), _trainingDateOf).length}', Icons.calendar_month_outlined),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_task_rounded, label: 'Тренировка', onTap: _assignTraining),
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () async {
          await _loadPlayerTrainingHistory(force: true);
          await _loadAttendanceLog(force: true);
          await _loadTeamCalendar(force: true);
          _rebuildOpenSectionSheet();
        }),
      ],
      children: [
        _buildInlineCalendarHeader(
          title: 'Календарь тренировок',
          subtitle: 'Дни с тренировками подсвечены. Нажмите дату, чтобы отфильтровать список.',
          expanded: _trainingCalendarExpanded,
          onToggle: () {
            setState(() => _trainingCalendarExpanded = !_trainingCalendarExpanded);
            _rebuildOpenSectionSheet();
          },
        ),
        if (_trainingCalendarExpanded) ...[
          const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: _trainingCalendarItems(),
            dateOf: _trainingDateOf,
            selectedDay: _selectedTrainingDay,
            onSelect: (d) {
              setState(() {
                _selectedTrainingDay = d;
                _eventFilterDate = d;
                selectedEvent = null;
                selectedEventPlayerInfo = null;
              });
              // Не перезагружаем список по одному дню: фильтруем уже загруженный месяц,
              // чтобы календарь сразу показывал все события месяца и не "схлопывался" до 1-2 записей.
              _rebuildOpenSectionSheet();
            },
            onDayWithItemsTap: (day, dayItems) {
              _showTrainingDayDetailsSheet(day, dayItems);
            },
          ),
        ],
        if (_selectedTrainingDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(
            date: _selectedTrainingDay!,
            label: 'Показаны тренировки за дату',
            onClear: () async {
              setState(() {
                _selectedTrainingDay = null;
                _eventFilterDate = null;
                selectedEvent = null;
                selectedEventPlayerInfo = null;
              });
              _rebuildOpenSectionSheet();
              await _loadPlayerTrainingHistory(force: true);
              await _loadAttendanceLog(force: true);
              _rebuildOpenSectionSheet();
            },
          ),
        ],
        const SizedBox(height: 12),
        _buildTrainingSubTabs(),
        const SizedBox(height: 14),
        if (_trainingSubTab == 0) _buildEventsSubTab(),
        if (_trainingSubTab == 1) _buildAttendanceSubTab(),
        if (_trainingSubTab == 2) _buildIndividualSubTab(),
      ],
    );
  }

  

  Widget _buildTrainingSubTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: isTablet ? 4.2 : 2.35,
          children: [
            _buildTrainingTabItem(
              title: 'Тренировки',
              subtitle: 'события',
              icon: Icons.sports_soccer_rounded,
              index: 0,
            ),
            _buildTrainingTabItem(
              title: 'Журнал',
              subtitle: 'посещ.',
              icon: Icons.fact_check_rounded,
              index: 1,
            ),
            _buildTrainingTabItem(
              title: 'Личные',
              subtitle: 'индив.',
              icon: Icons.fitness_center_rounded,
              index: 2,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrainingTabItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required int index,
  }) {
    final active = _trainingSubTab == index;
    final isWide = _isDesktopOrTablet(context);
    final accent = _AppColors.accentForIcon(icon);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isWide ? 22 : 18),
        onTap: () async {
          setState(() => _trainingSubTab = index);
          _rebuildOpenSectionSheet();
          if (index == 0) await _loadPlayerTrainingHistory(force: true);
          if (index == 1) await _loadAttendanceLog(force: true);
          _rebuildOpenSectionSheet();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 16 : 10,
            vertical: isWide ? 14 : 10,
          ),
          decoration: BoxDecoration(
            color: active ? _AppColors.softFor(accent) : _AppColors.cmrSoftPanel,
            borderRadius: BorderRadius.circular(isWide ? 22 : 18),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: isWide ? 42 : 34,
                height: isWide ? 42 : 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(active ? 0.95 : 0.86),
                  borderRadius: BorderRadius.circular(isWide ? 15 : 13),
                ),
                child: Icon(icon, color: accent, size: isWide ? 21 : 17),
              ),
              SizedBox(width: isWide ? 12 : 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w900,
                        fontSize: _adaptiveFont(context, mobile: 11.2, wide: 15.0),
                        color: const Color(0xFF101828),
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: _adaptiveFont(context, mobile: 9.2, wide: 12.2),
                        color: const Color(0xFF667085),
                        height: 1.05,
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

    return teamEvents.where((e) {
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
    list.sort((a, b) {
      final da = _parseEventDate(a) ?? DateTime(1970);
      final db = _parseEventDate(b) ?? DateTime(1970);
      return db.compareTo(da);
    });

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in list) {
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
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(
            children: [
              Text(
                _eventGroupTitle(k),
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: _adaptiveFont(context, mobile: 13, wide: 15.2),
                  color: _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: const SizedBox(height: 8)),
            ],
          ),
        ),
      );

      for (final e in groups[k]!) {
        final id = _asInt(e["event_id"] ?? e["id"]);
        final dateRaw = _asStr(e["date"] ?? e["start_at"] ?? e["day"]);
        final title =
            _asStr(e["title"]).isEmpty ? "Тренировка" : _asStr(e["title"]);
        final active = selectedEvent != null &&
            _asInt(selectedEvent?["event_id"] ?? selectedEvent?["id"]) == id;

        final rating = _asInt(e["player_rating"] ?? e["rating"] ?? 0).clamp(0, 5);

        out.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                await _loadPlayerInfoForEvent(id);
                _rebuildOpenSectionSheet();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active ? _primary.withOpacity(0.08) : _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? _primary.withOpacity(0.25)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: _isDesktopOrTablet(context) ? 52 : 44,
                      height: _isDesktopOrTablet(context) ? 52 : 44,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.sports_soccer_rounded, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.w900,
                              fontSize: _adaptiveFont(context, mobile: 13, wide: 15.2),
                              color: _textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateRaw.isEmpty ? _eventGroupTitle(k) : dateRaw,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.w600,
                              fontSize: _adaptiveFont(context, mobile: 11, wide: 12.6),
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rating > 0
                            ? Colors.amber.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: (rating > 0 ? Colors.amber : Colors.grey)
                                .withOpacity(0.25)),
                      ),
                      child: Text(
                        rating > 0 ? "$rating/5" : "-",
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w900,
                          fontSize: _adaptiveFont(context, mobile: 10, wide: 12.2),
                          color: rating > 0
                              ? Colors.amber.shade800
                              : _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: _isDesktopOrTablet(context) ? 22 : 16, color: _textSecondary),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return out;
  }


  Future<void> _showTrainingDayDetailsSheet(DateTime day, List<Map<String, dynamic>> rawItems) async {
    final rows = rawItems
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) => _parseEventDate(x) != null)
        .toList();

    if (!mounted || rows.isEmpty) return;

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
                          border: Border.all(color: _primary.withOpacity(0.16)),
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
                              style: _cmrTitleText(context, mobile: 18, wide: 19.2, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rows.length == 1
                                  ? 'Подробности, посещаемость, оценки и комментарии'
                                  : 'На эту дату найдено записей: ${rows.length}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
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

  Widget _buildTrainingDetailsSheetCard(Map<String, dynamic> e, BuildContext sheetContext) {
    final id = _asInt(e["event_id"] ?? e["id"]);
    final title = _firstNotEmpty([e["title"], e["event_title"], e["name"]]).trim();
    final date = _anyDateStr(e);
    final type = _firstNotEmpty([e["type"], e["training_type"], e["category"]]).trim();
    final typeLabel = _ruTrainingType(type);
    final description = _firstNotEmpty([e["description"], e["body"], e["details"]]).trim();
    final status = _attendanceStatusOf(e);
    final lateMin = _asInt(e["late_minutes"] ?? e["late"]);
    final meta = _statusMeta(status, lateMin);

    final playerRating = _firstRatingValue(e, const [
      "player_rating",
      "self_rating",
      "rating",
      "player_mark",
    ]);
    final coachRating = _firstRatingValue(e, const [
      "coach_rating",
      "trainer_rating",
      "coach_mark",
      "trainer_mark",
      "mark",
    ]);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
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
                  color: meta.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: meta.color.withOpacity(0.18)),
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
                      style: _titleStyle(size: 15, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (typeLabel.isNotEmpty) typeLabel,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 11.2, color: const Color(0xFF64748B), weight: FontWeight.w700),
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
                  border: Border.all(color: _AppColors.cmrBorder),
                ),
                child: TextField(
                  controller: _eventSearchC,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    hintText: "Поиск тренировки...",
                    prefixIcon: Icon(Icons.search_rounded, size: 17),
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontFamily: _fontFamily, fontSize: 12),
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
        if (selectedEvent != null) _buildSelectedEventPlayerInfoCard(),
      ],
    );
  }

  Widget _buildSelectedEventPlayerInfoCard() {
    if (selectedEventPlayerInfo == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (selectedEventPlayerInfo?["error"] != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: _asStr(selectedEventPlayerInfo?["error"]),
      );
    }

    final status = _firstNotEmpty([
      selectedEventPlayerInfo?["status"],
      selectedEventPlayerInfo?["attendance_status"],
      selectedEventPlayerInfo?["presence_status"],
    ]);
    final late = _asInt(selectedEventPlayerInfo?["late_minutes"] ?? selectedEventPlayerInfo?["late"]);
    final reason = _firstNotEmpty([
      selectedEventPlayerInfo?["reason"],
      selectedEventPlayerInfo?["absence_reason"],
    ]).trim();

    final playerRating = _firstRatingValue(selectedEventPlayerInfo, const [
      "player_rating",
      "self_rating",
      "rating",
      "player_mark",
    ]);
    final coachRating = _firstRatingValue(selectedEventPlayerInfo, const [
      "coach_rating",
      "trainer_rating",
      "coach_mark",
      "trainer_mark",
      "mark",
    ]);
    final coachComment = _firstNotEmpty([
      selectedEventPlayerInfo?["coach_comment"],
      selectedEventPlayerInfo?["trainer_comment"],
      selectedEventPlayerInfo?["comment"],
    ]).trim();
    final coachNote = _firstNotEmpty([
      selectedEventPlayerInfo?["coach_note"],
      selectedEventPlayerInfo?["trainer_note"],
      selectedEventPlayerInfo?["note_coach"],
    ]).trim();

    final meta = _statusMeta(status, late);
    final statusText = meta.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.014),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Тренировка — оценки и комментарий",
                  style: _titleStyle(size: 14, color: _textPrimary),
                ),
              ),
              Builder(
                builder: (context) {
                  final wide = MediaQuery.of(context).size.width >= 720;
                  return TextButton.icon(
                    onPressed: _openCoachNoteSheet,
                    icon: Icon(Icons.edit_note_rounded, size: wide ? 21 : 18),
                    label: Text(
                      "Заметка",
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: wide ? 13.5 : 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 15 : 10, vertical: wide ? 10 : 6),
                      backgroundColor: _primary.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(wide ? 16 : 12),
                        side: BorderSide(color: _primary.withOpacity(.18)),
                      ),
                      elevation: 0,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillInfo(meta.icon, "Статус", statusText, color: meta.color),
              _pillInfo(
                Icons.star_rounded,
                "Оценка игрока",
                playerRating == null ? "-" : "★ ${_asInt(playerRating)}/5",
                color: Colors.amber.shade700,
              ),
              _pillInfo(
                Icons.workspace_premium_rounded,
                "Оценка тренера",
                coachRating == null ? "-" : "★ ${_asInt(coachRating)}/5",
                color: Colors.blue.shade700,
              ),
              if (reason.isNotEmpty)
                _pillInfo(Icons.info_outline_rounded, "Причина", reason),
            ],
          ),
          if (coachComment.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(
                icon: Icons.chat_bubble_outline_rounded,
                title: "Комментарий тренера",
                text: coachComment),
          ],
          const SizedBox(height: 12),
          _noteBox(
            icon: Icons.sticky_note_2_outlined,
            title: "Заметка тренера (для себя)",
            text: coachNote.isEmpty
                ? "Пока нет заметки. Нажмите «Заметка», чтобы добавить."
                : coachNote,
            subtleWhenEmpty: coachNote.isEmpty,
          ),
        ],
      ),
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
          color: const Color(0xFF8B5CF6),
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
          color: const Color(0xFF64748B),
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                    style: _titleStyle(size: 14.5, color: const Color(0xFF0F172A)),
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
                .map((d) => Expanded(child: Center(child: Text(d, style: _bodyStyle(size: 10.5, color: const Color(0xFF64748B), weight: FontWeight.w900)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: total,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
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

                final coach = _firstRatingValue(row, const ["coach_rating", "trainer_rating", "coach_mark", "trainer_mark", "mark"]);
                if (coach != null) {
                  coachSum += _asInt(coach);
                  coachCnt++;
                }

                final player = _firstRatingValue(row, const ["player_rating", "self_rating", "rating", "player_mark"]);
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
                    border: Border.all(
                      color: selected
                          ? _primary.withOpacity(0.45)
                          : today
                              ? const Color(0xFFBFDBFE)
                              : _AppColors.cmrBorder,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: selected ? _primary : const Color(0xFF0F172A),
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
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        '$prefix$rating',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 7.4,
          fontWeight: FontWeight.w900,
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
        Text(label, style: _bodyStyle(size: 10.5, color: const Color(0xFF64748B), weight: FontWeight.w800)),
      ],
    );
  }

  Widget _activityLegendBadge(String prefix, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ratingTinyBadge(prefix, 5, prefix == 'Т' ? Colors.blue.shade700 : Colors.amber.shade800),
        const SizedBox(width: 5),
        Text(label, style: _bodyStyle(size: 10.5, color: const Color(0xFF64748B), weight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildAttendanceSubTab() {
    if (attendanceLoading) {
      return Center(child: CircularProgressIndicator(color: _primary));
    }
    if (attendanceError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: attendanceError!,
        action: TextButton(
          onPressed: () => _loadAttendanceLog(force: true),
          style: TextButton.styleFrom(foregroundColor: _primary),
          child: const Text("Повторить"),
        ),
      );
    }

    final total = attendanceLog.length;
    final missed =
        attendanceLog.where((x) => _attendanceStatusOf(x) == "absent").length;
    final sickCount = attendanceLog.where((x) {
      final s = _attendanceStatusOf(x);
      return s == "late" || s == "sick";
    }).length;
    final injuredCount = attendanceLog.where((x) {
      final s = _attendanceStatusOf(x);
      return s == "injured" || s == "trauma";
    }).length;

    int sumCoach = 0;
    int cntCoach = 0;
    for (final x in attendanceLog) {
      final r = _firstRatingValue(x, const ["coach_rating", "trainer_rating", "coach_mark", "trainer_mark", "mark"]);
      if (r != null) {
        sumCoach += _asInt(r);
        cntCoach++;
      }
    }
    final avgCoach = cntCoach == 0 ? 0.0 : (sumCoach / cntCoach);

    int discipline = 100 - (missed * 12);
    if (discipline < 0) discipline = 0;
    if (discipline > 100) discipline = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          title: "Активность игрока",
          icon: Icons.fact_check_rounded,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pillInfo(Icons.list_alt_rounded, "Тренировок", "$total"),
                _pillInfo(Icons.block_rounded, "Пропуски", "$missed",
                    color: const Color(0xFFEF4444)),
                _pillInfo(Icons.sick_rounded, "Болел", "$sickCount",
                    color: const Color(0xFFF59E0B)),
                _pillInfo(Icons.healing_rounded, "Травмы", "$injuredCount",
                    color: const Color(0xFF8B5CF6)),
                _pillInfo(
                  Icons.workspace_premium_rounded,
                  "Оценка тренера",
                  cntCoach == 0 ? "-" : avgCoach.toStringAsFixed(1),
                  color: Colors.blue.shade700,
                ),
                _pillInfo(Icons.shield_rounded, "Дисциплина",
                    "$discipline/100",
                    color: Colors.blueGrey.shade700),
              ],
            ),
            // Календарь уже расположен выше в разделе тренировок.
            // Здесь оставляем только сводку PRO, чтобы на странице не было двух календарей.
          ],
        ),
        const SizedBox(height: 12),
        if (attendanceLog.isEmpty)
          _buildEmptyState(
            icon: Icons.event_available_rounded,
            message: "Нет записей посещаемости за период.",
            action: TextButton(
              onPressed: () => _loadAttendanceLog(force: true),
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text("Обновить"),
            ),
          )
        else
          ...attendanceLog.map((x) {
            final eventTitle =
                _asStr(x["title"] ?? x["event_title"] ?? x["name"]).trim();
            final date = _anyDateStr(x);
            final st = _attendanceStatusOf(x);
            final lateMin = _asInt(x["late_minutes"] ?? x["late"]);
            final reason = _firstNotEmpty([x["reason"], x["absence_reason"]]).trim();

            final coachComment = _firstNotEmpty([x["coach_comment"], x["trainer_comment"], x["comment"]]).trim();
            final attendanceNote = _firstNotEmpty([x["note"], x["attendance_note"]]).trim();
            final coachNote = _firstNotEmpty([x["coach_note"], x["trainer_note"], x["note_coach"]]).trim();

            final meta = _statusMeta(st, lateMin);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _AppColors.cmrSoftPanel,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF101828).withOpacity(0.014),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                          color: _AppColors.softFor(meta.color),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 21),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date.isEmpty ? "Дата не указана" : date,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            if (eventTitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                eventTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontWeight: FontWeight.w700,
                                  color: _textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _AppColors.softFor(meta.color),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          meta.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontWeight: FontWeight.w900,
                            color: meta.color,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBox(
                        icon: Icons.info_outline_rounded,
                        title: "Причина",
                        text: reason),
                  ],
                  if (coachComment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBox(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: "Комментарий тренера",
                        text: coachComment),
                  ],
                  if (attendanceNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBox(
                        icon: Icons.fact_check_outlined,
                        title: "Заметка посещения",
                        text: attendanceNote),
                  ],
                  if (coachNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBox(
                        icon: Icons.sticky_note_2_outlined,
                        title: "Заметка тренера",
                        text: coachNote),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildIndividualSubTab() {
    final playerId = _asInt(widget.player["user_id"]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AppColors.cmrBorder),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF2563EB), size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Личные тренировки', style: _titleStyle(size: 15, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 3),
                        Text(
                          'История индивидуальной нагрузки, задания и контроль выполнения',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  _buildCmrActionChip(
                    icon: Icons.add_task_rounded,
                    label: 'Назначить',
                    onTap: _assignTraining,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 620;
                  return GridView.count(
                    crossAxisCount: wide ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: wide ? 3.2 : 2.55,
                    children: [
                      _buildCmrMiniStat('Формат', 'Личные', Icons.person_pin_circle_outlined),
                      _buildCmrMiniStat('Контроль', 'Тренер', Icons.verified_user_outlined),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: _AppColors.cmrSoftPanel,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TrainingHistoryWidget(playerId: playerId),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCalendarBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.018),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                      border: Border.all(color: _primary.withOpacity(0.18)),
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
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                                fontSize: 12),
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
    final type = _asStr(e["type"]).trim();
    final typeLabel = _ruTrainingType(type);
    final title =
        _asStr(e["title"]).trim().isEmpty ? "Событие" : _asStr(e["title"]).trim();
    final startAt = _fmtTime(_asStr(e["start_at"]));
    final endAt = _fmtTime(_asStr(e["end_at"]));
    final location = _asStr(e["location"]).trim();
    final notes = _asStr(e["notes"]).trim();

    IconData icon = Icons.event_note_rounded;
    if (type.toLowerCase().contains("train")) icon = Icons.sports_soccer_rounded;
    if (type.toLowerCase().contains("match")) icon = Icons.emoji_events_rounded;
    if (type.toLowerCase().contains("meet")) icon = Icons.groups_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.014),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: _textPrimary,
                      height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  endAt.isEmpty ? startAt : "$startAt — $endAt",
                  style: TextStyle(
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: _textSecondary),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "📍 $location",
                    style: TextStyle(
                        fontFamily: _fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: _textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (typeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          color: _primary),
                    ),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _noteBox(
                      icon: Icons.info_outline_rounded,
                      title: "Заметки",
                      text: notes),
                ],
              ],
            ),
          ),
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
    final withNotes = matches.where((x) => _asStr(x["notes"]).trim().isNotEmpty).length;

    return _buildCmrSectionShell(
      title: 'Матчи игрока',
      subtitle: 'Список матчей в формате таблицы: дата, соперник, счёт, турнир, видео и ТТД',
      icon: Icons.table_chart_rounded,
      stats: [
        _buildCmrMiniStat('Матчи', '${matches.length}', Icons.sports_score_outlined),
        _buildCmrMiniStat('Видео', '$withVideo', Icons.play_circle_outline_rounded),
        _buildCmrMiniStat('ТТД', '$withTtd', Icons.analytics_outlined),
        _buildCmrMiniStat('Заметки', '$withNotes', Icons.chat_bubble_outline_rounded),
      ],
      actions: [
        _buildCmrEditButton(icon: Icons.add_circle_outline_rounded, label: 'Матч', onTap: () => _showEditMatchDialog()),
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => _loadMatches(force: true)),
      ],
      children: [
        _buildInlineCalendarHeader(
          title: 'Календарь матчей',
          subtitle: 'Даты с матчами отмечены. Выбор даты фильтрует таблицу.',
          expanded: _matchesCalendarExpanded,
          onToggle: () {
            setState(() => _matchesCalendarExpanded = !_matchesCalendarExpanded);
            _rebuildOpenSectionSheet();
          },
        ),
        if (_matchesCalendarExpanded) ...[
          const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: matches,
            dateOf: _matchDateOf,
            selectedDay: _selectedMatchDay,
            onSelect: (d) {
              setState(() => _selectedMatchDay = d);
              _rebuildOpenSectionSheet();
            },
            onDayWithItemsTap: (day, dayMatches) {
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
        if (matches.isNotEmpty) ...[
          _buildPlayerTtdMatchSelector(),
          const SizedBox(height: 12),
        ],
        if (matchesLoading)
          _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())))
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
          _buildMatchesTable(selectedMatches),
      ],
    );
  }


  Future<void> _showMatchDayDetailsSheet(DateTime day, List<Map<String, dynamic>> dayMatches) async {
    final rows = dayMatches
        .map((x) => Map<String, dynamic>.from(x))
        .toList();

    if (!mounted || rows.isEmpty) return;

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
                          border: Border.all(color: _primary.withOpacity(0.16)),
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
                              style: _cmrTitleText(context, mobile: 18, wide: 19.2, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rows.length == 1 ? 'Подробная информация по выбранной игре' : 'На эту дату найдено матчей: ${rows.length}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
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
        border: Border.all(color: _AppColors.cmrBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                  border: Border.all(color: _primary.withOpacity(0.14)),
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
                      style: _titleStyle(size: 15, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (date.isNotEmpty) date,
                        if (tournament.isNotEmpty) tournament,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 11.2, color: const Color(0xFF64748B), weight: FontWeight.w700),
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
                  border: Border.all(color: _primary.withOpacity(0.12)),
                ),
                child: Text(
                  score,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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
        border: Border.all(color: c.withOpacity(0.24), width: wide ? 1.2 : 1),
        boxShadow: wide
            ? [
                BoxShadow(
                  color: c.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: wide ? 17 : 14, color: c),
          SizedBox(width: wide ? 7 : 5),
          Text(
            '$title: ',
            style: _bodyStyle(size: wide ? 12.2 : 10.8, color: const Color(0xFF475569), weight: FontWeight.w900),
          ),
          Text(
            value,
            style: _bodyStyle(size: wide ? 12.2 : 10.8, color: c, weight: FontWeight.w900),
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                    style: _bodyStyle(size: 11.5, color: const Color(0xFF0F172A), weight: FontWeight.w900),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _AppColors.cmrBorder)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Дата', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('Соперник', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Счёт', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('Турнир', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Видео/ТТД', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
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
        if (day != null) {
          setState(() => _selectedMatchDay = day);
          _rebuildOpenSectionSheet();
        }
        _showMatchDayDetailsSheet(day ?? DateTime.now(), [m]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _AppColors.cmrBorder))),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(date.isEmpty ? '—' : date, style: _bodyStyle(size: 12.5, color: const Color(0xFF0F172A), weight: FontWeight.w800))),
            Expanded(flex: 3, child: Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.8, color: const Color(0xFF0F172A), weight: FontWeight.w900))),
            Expanded(flex: 2, child: Text(score, textAlign: TextAlign.center, style: _bodyStyle(size: 12.8, color: const Color(0xFF0F172A), weight: FontWeight.w900))),
            Expanded(flex: 3, child: Text(tournament, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.2, color: const Color(0xFF64748B), weight: FontWeight.w700))),
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
        border: Border.all(color: active ? const Color(0xFFBFDBFE) : _AppColors.cmrBorder),
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
      border: Border.all(color: _AppColors.cmrBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
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
                border: Border.all(color: _primary.withOpacity(0.12)),
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
                  fontWeight: FontWeight.w900,
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                  TextSpan(text: '$title: ', style: _bodyStyle(size: compact ? 10.8 : 11.2, color: _textPrimary, weight: FontWeight.w900)),
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
            border: Border.all(color: onTap == null ? _AppColors.cmrBorder : _primary.withOpacity(wide ? .20 : .12)),
            boxShadow: wide && !compact && onTap != null
                ? [
                    BoxShadow(
                      color: _primary.withOpacity(.07),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 14 : (wide ? 18 : 15), color: fg),
              SizedBox(width: wide && !compact ? 7 : 5),
              Text(label, style: _bodyStyle(size: compact ? 10.8 : (wide ? 12.6 : 11.2), color: fg, weight: FontWeight.w900)),
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
                  border: Border.all(color: _primary.withOpacity(0.15)),
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
                fontWeight: FontWeight.w900,
                fontSize: compact ? 10.5 : 11,
                color: active ? Colors.white : _textPrimary,
              ),
              selectedColor: _primary,
              backgroundColor: Colors.white,
              side: BorderSide(color: active ? _primary : _AppColors.cmrBorder),
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 9.8 : 10.5, color: _textSecondary, weight: FontWeight.w800)),
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
        border: Border.all(color: _AppColors.cmrBorder),
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
              Text('${metricCards.length}', style: _bodyStyle(size: compact ? 10.5 : 11, color: _textSecondary, weight: FontWeight.w900)),
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
        border: Border.all(color: _AppColors.cmrBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: compact ? 10.2 : 10.8, color: _textSecondary, weight: FontWeight.w800)),
          SizedBox(height: compact ? 5 : 6),
          Row(
            children: [
              Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: compact ? 14 : 15.5, color: _textPrimary))),
              if (percent != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7, vertical: 3),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.09), borderRadius: BorderRadius.circular(999)),
                  child: Text('${percent.toStringAsFixed(0)}%', style: _bodyStyle(size: compact ? 9.5 : 10, color: _primary, weight: FontWeight.w900)),
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
        _buildInlineCalendarHeader(
          title: 'Календарь дневника',
          subtitle: 'Даты с записями подсвечены. Выберите день, чтобы отфильтровать историю.',
          expanded: _diaryCalendarExpanded,
          onToggle: () => setState(() => _diaryCalendarExpanded = !_diaryCalendarExpanded),
        ),
        if (_diaryCalendarExpanded) ...[
          const SizedBox(height: 10),
          _buildMarkedCalendar(
            items: diaryItems,
            dateOf: _diaryDateOf,
            selectedDay: _selectedDiaryDay,
            onSelect: (d) => setState(() => _selectedDiaryDay = d),
          ),
        ],
        if (_selectedDiaryDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(
            date: _selectedDiaryDay!,
            label: 'Показаны записи за дату',
            onClear: () => setState(() => _selectedDiaryDay = null),
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

    return _buildCmrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AppColors.cmrBorder),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text(date.isEmpty ? 'Дата не указана' : date, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.5, color: const Color(0xFF64748B), weight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _AppColors.cmrBorder),
                ),
                child: Text('$rating/5', style: _bodyStyle(size: 11.5, color: const Color(0xFF0F172A), weight: FontWeight.w900)),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(icon: Icons.sticky_note_2_outlined, title: 'Заметка игрока', text: note),
          ],
        ],
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
    final initialMetrics = metrics.isNotEmpty
        ? List<String>.from(metrics)
        : _asStr(widget.player['sport_data'])
            .split('\n')
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
                  border: Border.all(color: _AppColors.cmrBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.035),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                        style: _bodyStyle(size: isTablet ? 13 : 12.2, color: const Color(0xFF0F172A), weight: FontWeight.w800),
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
                        style: _bodyStyle(size: isTablet ? 13 : 12.2, color: const Color(0xFF0F172A), weight: FontWeight.w800),
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
                                border: Border.all(color: _AppColors.cmrBorder),
                              ),
                              child: const Icon(Icons.query_stats_rounded, color: Color(0xFF178A45), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Редактор метрик', style: _titleStyle(size: isTablet ? 20 : 18, color: const Color(0xFF0F172A))),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Добавляйте показатели отдельными строками: рост, вес, голы, передачи, скорость и любые свои метрики.',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: _bodyStyle(size: isTablet ? 12.5 : 11.5, color: const Color(0xFF64748B), weight: FontWeight.w700),
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
                            border: Border.all(color: _AppColors.cmrBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF178A45), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Название и значение разделены на два поля — так карточки метрик будут выглядеть ровно и на телефоне, и на планшете.',
                                  style: _bodyStyle(size: 11.6, color: const Color(0xFF14532D), weight: FontWeight.w800),
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
                          label: const Text('Добавить показатель', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF178A45),
                            side: const BorderSide(color: _AppColors.cmrBorder),
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
                                  side: const BorderSide(color: _AppColors.cmrBorder),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: saving ? null : () => saveMetrics(setModalState),
                                icon: saving
                                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(saving ? 'Сохраняю...' : 'Сохранить', style: const TextStyle(fontWeight: FontWeight.w900)),
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
                    border: Border.all(color: selected ? const Color(0xFF178A45) : _AppColors.cmrBorder),
                    boxShadow: selected
                        ? [BoxShadow(color: const Color(0xFF178A45).withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item['icon'] as IconData, size: 17, color: selected ? const Color(0xFF178A45) : const Color(0xFF64748B)),
                      SizedBox(width: _isDesktopOrTablet(context) ? 12 : 7),
                      Text(title, style: _bodyStyle(size: 12, color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B), weight: FontWeight.w900)),
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
                    border: Border.all(color: _AppColors.cmrBorder),
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
                            Text('Карточка достижения', style: _titleStyle(size: 15, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Text('Заполните коротко: тип, дата, турнир и описание. Это будет красиво отображаться в портфолио игрока.', style: _bodyStyle(size: 11.5, color: const Color(0xFF64748B), weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Тип достижения', style: _titleStyle(size: 13.5, color: const Color(0xFF0F172A))),
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
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _AppColors.cmrSoftPanel,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withOpacity(0.014),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
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
              child: const Icon(Icons.calendar_month_rounded, color: _AppColors.cmrGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 15, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 11.8, color: const Color(0xFF64748B), weight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMarkedCalendar({
    required List<Map<String, dynamic>> items,
    required DateTime? Function(Map<String, dynamic>) dateOf,
    required DateTime? selectedDay,
    required ValueChanged<DateTime> onSelect,
    void Function(DateTime day, List<Map<String, dynamic>> dayItems)? onDayWithItemsTap,
  }) {
    final now = DateTime.now();
    final base = selectedDay ?? now;
    final month = DateTime(base.year, base.month, 1);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.014),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _calendarArrow(Icons.chevron_left_rounded, () => onSelect(DateTime(month.year, month.month - 1, 1))),
              Expanded(child: Center(child: Text(DateFormat('LLLL yyyy', 'ru').format(month), style: _titleStyle(size: 14.5, color: const Color(0xFF0F172A))))),
              _calendarArrow(Icons.chevron_right_rounded, () => onSelect(DateTime(month.year, month.month + 1, 1))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => Expanded(child: Center(child: Text(d, style: _bodyStyle(size: 10.5, color: const Color(0xFF64748B), weight: FontWeight.w900)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: total,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
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

              for (final item in dayItems) {
                final st = _attendanceStatusOf(item);
                if (status.isEmpty || st == 'absent' || st == 'late' || st == 'injured' || st == 'sick') {
                  status = st;
                }

                final coach = _firstRatingValue(item, const [
                  'coach_rating',
                  'trainer_rating',
                  'coach_mark',
                  'trainer_mark',
                  'mark',
                ]);
                if (coach != null) {
                  coachSum += _asInt(coach);
                  coachCnt++;
                }

                final player = _firstRatingValue(item, const [
                  'player_rating',
                  'self_rating',
                  'rating',
                  'player_mark',
                ]);
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
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  onSelect(day);
                  if (has) {
                    onDayWithItemsTap?.call(day, dayItems);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? _AppColors.cmrGreen : has ? _AppColors.cmrSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? _AppColors.cmrGreen : today ? _AppColors.cmrGreen.withOpacity(0.20) : Colors.transparent),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$dayNum', style: TextStyle(color: selected ? Colors.white : const Color(0xFF0F172A), fontSize: 12.2, fontWeight: FontWeight.w900)),
                          if (has) ...[
                            const SizedBox(width: 3),
                            Container(
                              constraints: const BoxConstraints(minWidth: 14),
                              height: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(color: selected ? Colors.white : _AppColors.cmrGreen, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Text('$count', style: TextStyle(color: selected ? _AppColors.cmrGreen : Colors.white, fontSize: 8.2, fontWeight: FontWeight.w900))),
                            ),
                          ],
                        ],
                      ),
                      if (has) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: selected ? Colors.white : meta.color, shape: BoxShape.circle),
                        ),
                        if (coachAvg > 0 || playerAvg > 0) ...[
                          const SizedBox(height: 3),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              if (coachAvg > 0) _ratingTinyBadge('Т', coachAvg, selected ? Colors.white : Colors.blue.shade700),
                              if (playerAvg > 0) _ratingTinyBadge('И', playerAvg, selected ? Colors.white : Colors.amber.shade800),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AppColors.cmrBorder)),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.filter_alt_rounded, color: _AppColors.cmrGreen, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$label: ${DateFormat('dd.MM.yyyy').format(date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                size: 12.4,
                color: const Color(0xFF1F7A4D),
                weight: FontWeight.w900,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: _AppColors.cmrGreen, size: 18),
            ),
          ),
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
      final results = selected == null ? <Map<String, dynamic>>[] : await _loadPlayerTestingResultsForDate(selected, sessionsOut);

      if (!mounted) return;
      setState(() {
        playerTestingSessions = sessionsOut;
        _selectedTestingDay = selected;
        playerTestingResults = results;
        playerTestingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        playerTestingError = '$e';
        playerTestingLoading = false;
      });
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
      if (m != null) return (m.group(1) ?? '').trim();
      final p = RegExp(r'points:\s*([^,}]+)').firstMatch(text);
      if (p != null) return (p.group(1) ?? '').trim();
      return '';
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
      playerTestingLoading = true;
      playerTestingError = null;
    });

    try {
      final rows = await _loadPlayerTestingResultsForDate(_selectedTestingDay!, playerTestingSessions);
      if (!mounted) return;
      setState(() {
        playerTestingResults = rows;
        playerTestingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        playerTestingError = '$e';
        playerTestingLoading = false;
      });
    }
  }

  Widget _buildTestingHistoryTab() {
    return _buildCmrSectionShell(
      title: 'Тестирование игрока',
      subtitle: 'История CMR Testing по датам: календарь свернут по умолчанию',
      icon: Icons.fact_check_rounded,
      stats: [
        _buildCmrMiniStat('Даты', '${playerTestingSessions.length}', Icons.event_available_outlined),
        _buildCmrMiniStat('Показатели', '${playerTestingResults.length}', Icons.speed_rounded),
        _buildCmrMiniStat('Этап', _testingStageCode(), Icons.flag_outlined),
        _buildCmrMiniStat('Календарь', _testingCalendarExpanded ? 'Открыт' : 'Свернут', Icons.calendar_month_outlined),
      ],
      actions: [
        _buildCmrActionChip(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => _loadPlayerTestingHistory(force: true)),
      ],
      children: [
        _buildInlineCalendarHeader(
          title: 'Календарь тестирования',
          subtitle: 'Откройте календарь, чтобы выбрать дату тестов игрока.',
          expanded: _testingCalendarExpanded,
          onToggle: () => setState(() => _testingCalendarExpanded = !_testingCalendarExpanded),
        ),
        if (_testingCalendarExpanded) ...[
          const SizedBox(height: 10),
          _buildMarkedCalendar(items: playerTestingSessions, dateOf: _testingDateOf, selectedDay: _selectedTestingDay, onSelect: _selectPlayerTestingDate),
        ],
        if (_selectedTestingDay != null) ...[
          const SizedBox(height: 10),
          _buildSelectedDayFilterChip(date: _selectedTestingDay!, label: 'Выбрана дата тестирования', onClear: () => setState(() { _selectedTestingDay = null; playerTestingResults = []; })),
        ],
        const SizedBox(height: 12),
        if (playerTestingLoading)
          _buildCmrCard(child: const Center(child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator())))
        else if (playerTestingError != null)
          _buildEmptyState(icon: Icons.error_outline_rounded, message: playerTestingError!, action: TextButton(onPressed: () => _loadPlayerTestingHistory(force: true), child: const Text('Повторить')))
        else if (playerTestingSessions.isEmpty)
          _buildEmptyState(icon: Icons.fact_check_outlined, message: 'По игроку пока нет дат тестирования.')
        else if (playerTestingResults.isEmpty)
          _buildEmptyState(icon: Icons.info_outline_rounded, message: 'На выбранную дату результаты игрока не найдены.')
        else
          _buildTestingResultsTable(playerTestingResults),
      ],
    );
  }

  Widget _buildTestingResultsTable(List<Map<String, dynamic>> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _AppColors.cmrBorder)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('Тест', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Значение', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Категория', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
              ],
            ),
          ),
          ...rows.map((r) {
            final unit = _asStr(r['unit']);
            final baseValue = _testingValueText(r['value']);
            final value = '${baseValue.isEmpty ? '—' : baseValue}${unit.isEmpty || baseValue.isEmpty ? '' : ' $unit'}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _AppColors.cmrBorder))),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(_asStr(r['title']), maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle(size: 12.8, color: const Color(0xFF0F172A), weight: FontWeight.w900))),
                  Expanded(flex: 2, child: Text(value, textAlign: TextAlign.center, style: _bodyStyle(size: 12.8, color: const Color(0xFF0F172A), weight: FontWeight.w900))),
                  Expanded(flex: 2, child: Text(_testingCategoryTitle(_asStr(r['category'])), textAlign: TextAlign.right, style: _bodyStyle(size: 11.5, color: const Color(0xFF64748B), weight: FontWeight.w700))),
                ],
              ),
            );
          }),
        ],
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
                      border: Border.all(color: _AppColors.cmrBorder),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF178A45), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playerName.isEmpty ? 'Карточка игрока' : playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 18, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text('PDF будет сформирован с шапкой «Спортотека» и основными разделами профиля.', style: _bodyStyle(size: 12.5, color: const Color(0xFF64748B), weight: FontWeight.w700)),
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
          border: Border.all(color: _AppColors.cmrBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF178A45)),
            const SizedBox(width: 6),
            Text(label, style: _bodyStyle(size: 11.5, color: const Color(0xFF334155), weight: FontWeight.w900)),
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
                    decoration: BoxDecoration(color: const Color(0xFFEAF5EE), borderRadius: BorderRadius.circular(16), border: Border.all(color: _AppColors.cmrBorder)),
                    child: Icon(icon, color: const Color(0xFF178A45), size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _titleStyle(size: 18, color: const Color(0xFF0F172A))),
                        const SizedBox(height: 3),
                        Text(subtitle, style: _bodyStyle(size: 12, color: const Color(0xFF64748B), weight: FontWeight.w700)),
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
                        side: const BorderSide(color: _AppColors.cmrBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w900)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _AppColors.cmrBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _AppColors.cmrBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF178A45), width: 1.4)),
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
      border: Border.all(color: _primary.withOpacity(0.10)),
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
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
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
    final c = color ?? _AppColors.cmrGreen;
    final wide = MediaQuery.of(context).size.width >= 720;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 13 : 10, vertical: wide ? 9 : 7),
      decoration: BoxDecoration(
        color: _AppColors.softFor(c),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: wide ? 24 : 21,
            height: wide ? 24 : 21,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.86),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: wide ? 14 : 12, color: c),
          ),
          SizedBox(width: wide ? 7 : 5),
          Text(
            "$title: ",
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: wide ? 12.4 : 10.6,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: wide ? 12.4 : 10.6,
              color: c,
              fontWeight: FontWeight.w900,
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
      border: Border.all(color: _primary.withOpacity(0.16)),
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
              fontWeight: FontWeight.w900,
              color: _primary,
              fontSize: 12,
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
    final accent = _AppColors.accentForIcon(icon);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.cmrSoftPanel,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(0.018),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _AppColors.softFor(accent),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _cmrTitleText(
                    context,
                    mobile: 17.0,
                    wide: 19.0,
                    color: const Color(0xFF101828),
                    weight: FontWeight.w800,
                  ),
                ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 42,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: _AppColors.textSecondary,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 58,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: _AppColors.textPrimary,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
    final isEdit = record != null;
    final typeController = TextEditingController(text: isEdit ? _asStr(record['type']) : '');
    final titleController = TextEditingController(text: isEdit ? _asStr(record['title']) : '');
    final valueController = TextEditingController(text: isEdit ? _asStr(record['value']) : '');
    final commentController = TextEditingController(text: isEdit ? _asStr(record['comment']) : '');
    DateTime selectedDate = DateTime.tryParse(isEdit ? _asStr(record['date']) : '') ?? DateTime.now();
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
                  request.fields['id'] = _asStr(record['id']);
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.08),
                                blurRadius: 18,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isUploading ? null : () => Navigator.of(sheetContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _AppColors.textPrimary,
                                    side: const BorderSide(color: _AppColors.cmrBorder),
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text(
                                    'Отмена',
                                    style: TextStyle(fontWeight: FontWeight.w900),
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
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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
        border: Border.all(color: _AppColors.cmrBorder),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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
                    fontSize: 12,
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
                border: Border.all(color: _AppColors.cmrBorder),
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
        border: Border.all(color: _AppColors.cmrBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
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
          border: Border.all(color: active ? _AppColors.primaryGreen : _AppColors.cmrBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
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
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
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
          borderSide: const BorderSide(color: _AppColors.cmrBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _AppColors.cmrBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _AppColors.primaryGreen, width: 1.3),
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
          border: Border.all(color: _AppColors.cmrBorder),
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
                    style: TextStyle(color: _AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd.MM.yyyy').format(date),
                    style: const TextStyle(color: _AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w900),
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
          border: Border.all(color: _AppColors.cmrBorder),
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
              style: const TextStyle(color: _AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
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
        border: Border.all(color: _AppColors.primaryGreen.withOpacity(.18)),
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
              style: const TextStyle(color: _AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
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

    if (_selectedTabIndex == 6) await _loadDiary();

    if (_selectedTabIndex == 4) {
      await _loadTrainingSectionData(force: true);
    }

    if (_selectedTabIndex == 5) await _loadMatches(force: true);
    if (_selectedTabIndex == 7) await _loadPlayerTestingHistory(force: true);
  }

  Future<void> _selectCmrTab(int index) async {
    setState(() => _selectedTabIndex = index);

    if (index == 6) await _loadDiary();
    if (index == 7) {
      await _loadPlayerTestingHistory(force: false);
    }

    if (index == 4) {
      await _loadTrainingSectionData(force: true);
    }

    if (index == 5) await _loadMatches();
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
        return _AppColors.blue;
      case 1:
        return _AppColors.purple;
      case 2:
        return _AppColors.orange;
      case 3:
        return _AppColors.error;
      case 4:
        return _AppColors.blue;
      case 5:
        return _AppColors.blue;
      case 6:
        return _AppColors.teal;
      case 7:
        return _AppColors.purple;
      case 8:
        return _AppColors.orange;
      default:
        return _AppColors.blue;
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
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
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
              boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(.018), blurRadius: 16, offset: const Offset(0, 7))],
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
                  const Text('Закрыть профиль', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF101828), fontSize: 13, fontWeight: FontWeight.w800, height: 1)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrShellSidebar({required bool compact}) {
    final photo = _normalizeImage(widget.player["photo"]) ?? '';
    final name = _cmrFullName();
    final team = _playerClub().isEmpty
        ? _firstNotEmpty([widget.player["team_name"], widget.player["teamName"]])
        : _playerClub();
    final position = _firstNotEmpty([
      widget.player["position"],
      widget.player["role"],
      widget.player["amplua"],
    ]);

    return Container(
      width: compact ? 96 : 286,
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 14, compact ? 10 : 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(.045),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPlayerSidebarHeader(
            compact: compact,
            photo: photo,
            name: name,
            team: team,
            position: position,
          ),
          const SizedBox(height: 12),
          if (!compact) _buildPlayerSidebarStatusCard(),
          if (!compact) const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: _categoryTabs.length,
              separatorBuilder: (_, __) => SizedBox(height: compact ? 6 : 7),
              itemBuilder: (_, index) {
                final tab = _categoryTabs[index];
                final active = tab.index == _selectedTabIndex;
                final accent = _cmrTabAccent(tab.index);

                final tile = _buildPlayerSidebarTab(
                  tab: tab,
                  active: active,
                  accent: accent,
                  compact: compact,
                );

                if (compact) {
                  return Tooltip(
                    message: '${tab.title}\n${tab.subtitle}',
                    waitDuration: const Duration(milliseconds: 350),
                    child: tile,
                  );
                }

                return tile;
              },
            ),
          ),
          const SizedBox(height: 12),
          compact
              ? _buildCmrSidebarIconButton(
                  icon: Icons.edit_outlined,
                  onTap: _openPlayerEditorPanel,
                )
              : _buildCmrSidebarButton(
                  icon: Icons.edit_outlined,
                  label: 'Редактировать профиль',
                  onTap: _openPlayerEditorPanel,
                ),
        ],
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
    if (compact) {
      return Column(
        children: [
          _buildPhotoPreviewTap(
            imageUrl: photo,
            child: _buildCircleNetworkImage(
              imageUrl: photo,
              size: 54,
              borderColor: _AppColors.cmrBorder,
              borderWidth: 1,
              fallback: const Icon(Icons.person_rounded, color: _AppColors.primaryGreen),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 11.5,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _buildPhotoPreviewTap(
            imageUrl: photo,
            child: _buildCircleNetworkImage(
              imageUrl: photo,
              size: 54,
              borderColor: _AppColors.cmrBorder,
              borderWidth: 1,
              fallback: const Icon(Icons.person_rounded, color: _AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  team.isEmpty ? 'Профиль игрока' : team,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (position.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _AppColors.cmrSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _AppColors.primaryGreen.withOpacity(.14)),
                    ),
                    child: Text(
                      position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.primaryGreen,
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSidebarStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FAF5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _AppColors.primaryGreen.withOpacity(.12)),
            ),
            child: const Icon(Icons.verified_rounded, size: 18, color: _AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Меню игрока',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Все разделы профиля',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.1,
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

  Widget _buildPlayerSidebarTab({
    required _CategoryTab tab,
    required bool active,
    required Color accent,
    required bool compact,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _handleCmrSidebarTabTap(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: compact ? 54 : 56),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 12,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF7F0) : const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                width: compact ? 42 : 38,
                height: compact ? 42 : 38,
                decoration: BoxDecoration(
                  color: active ? Colors.white : _AppColors.softFor(accent),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  tab.icon,
                  size: compact ? 21 : 20,
                  color: active ? accent : _AppColors.textSecondary,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _AppColors.textPrimary : const Color(0xFF334155),
                          fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                          fontSize: 13.2,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? accent : _AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.8,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: active ? 1 : .45,
                  child: Icon(
                    active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                    color: active ? accent : _AppColors.textTertiary,
                    size: active ? 18 : 20,
                  ),
                ),
              ],
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
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _AppColors.primaryGreen.withOpacity(.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
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

  Widget _buildCmrSidebarIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Редактировать профиль',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _AppColors.primaryGreen.withOpacity(.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
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
    final rightWidth = compact ? 560.0 : 660.0;

    if (tab.index == 0) {
      return Row(
        key: const ValueKey('player-window-profile'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildCmrCenterPane(tab)),
          const SizedBox(width: 12),
          SizedBox(width: rightWidth, child: _buildCmrDetailsPane(tab)),
        ],
      );
    }

    return Container(
      key: ValueKey('player-window-tab-${tab.index}'),
      color: Colors.white,
      child: _buildTabContentByIndex(tab.index),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(.045),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
                    color: _AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _AppColors.teal.withOpacity(.14)),
                  ),
                  child: const Icon(Icons.edit_rounded, color: _AppColors.teal, size: 22),
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
                          color: Color(0xFF111827),
                          fontSize: 17,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
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
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: EditPlayerScreen(
              initialPlayer: widget.player,
              embedded: true,
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

  Widget _buildGeneralDetailsActionsPane() {
    final photo = _normalizeImage(widget.player['photo']);
    final name = _cmrFullName();
    final position = _firstNotEmpty([widget.player['position'], widget.player['player_position']]);
    final number = _firstNotEmpty([widget.player['jersey_number'], widget.player['number'], widget.player['player_number']]);
    final team = _playerClub().isEmpty ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']]) : _playerClub();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _buildPhotoPreviewTap(
                imageUrl: photo,
                child: _buildCircleNetworkImage(
                  imageUrl: photo,
                  size: 64,
                  borderColor: _AppColors.cmrBorder,
                  borderWidth: 1,
                  fallback: const Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111827), fontSize: 22, fontWeight: FontWeight.w900, height: 1.05)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _buildNeutralInfoPill(position.isEmpty ? 'Амплуа —' : position),
                        _buildNeutralInfoPill(number.isEmpty ? '№ —' : '№ $number'),
                        if (team.isNotEmpty) _buildNeutralInfoPill(team),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SmallCardEditButton(label: 'Профиль', icon: Icons.open_in_new_rounded, onTap: _openPlayerEditorPanel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCmrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Действия с профилем', style: _titleStyle(size: 17, color: const Color(0xFF0F172A))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCmrActionChip(icon: Icons.edit_outlined, label: 'Редактировать', onTap: _openPlayerEditorPanel, compact: true),
                  _buildCmrActionChip(icon: Icons.chat_bubble_outline_rounded, label: 'Написать', onTap: _openPrivateChat, compact: true),
                  _buildCmrActionChip(icon: Icons.event_available_outlined, label: 'Тренировка', onTap: _assignTraining, compact: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildStyledSectionCard(title: 'Контакты', icon: Icons.alternate_email_rounded, child: _buildContactsContent()),
        const SizedBox(height: 12),
        _buildStyledSectionCard(title: 'Спортивные данные', icon: Icons.sports_soccer_rounded, child: _buildSportDataContent()),
      ],
    );
  }

  Widget _buildNeutralInfoPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w900)),
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
      return Text('Спортивные данные пока не заполнены.', style: _bodyStyle(size: 12.5, color: const Color(0xFF64748B), weight: FontWeight.w700));
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
                border: Border.all(color: accent.withOpacity(.24), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                      border: Border.all(color: accent.withOpacity(.18)),
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
                        color: const Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
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
            border: Border.all(color: _AppColors.cmrBorder),
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
                      border: Border.all(color: _AppColors.cmrBorder),
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
                          style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF0F172A), fontSize: _adaptiveFont(context, mobile: 18, wide: 19.2), fontWeight: FontWeight.w900, height: 1.1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Подсказки можно свернуть. Все данные, цифры, редакторы и кнопки действий находятся справа.',
                          style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF64748B), fontSize: _adaptiveFont(context, mobile: 12.5, wide: 13.2), height: 1.35, fontWeight: FontWeight.w700),
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
                          border: Border.all(color: _AppColors.cmrBorder),
                        ),
                        child: const Icon(Icons.keyboard_arrow_left_rounded, color: Color(0xFF64748B), size: 22),
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
          {'title': 'Календарь', 'text': 'Справа дни с тренировками подсвечиваются. Нажмите дату, чтобы отфильтровать список.'},
          {'title': 'Журнал', 'text': 'Внутри раздела тренировки есть вкладка журнала посещаемости без отдельного дневника.'},
          {'title': 'Личные задания', 'text': 'Индивидуальные задания отделены от командных тренировок.'},
        ];
      case 5:
        return const [
          {'title': 'Таблица матчей', 'text': 'Матчи справа представлены строками: дата, соперник, счёт, турнир, видео и ТТД.'},
          {'title': 'Календарь матчей', 'text': 'Разверните календарь и выберите дату — список сразу станет короче.'},
          {'title': 'Анализ', 'text': 'По нажатию на строку можно перейти к подробностям, видео или ТТД матча.'},
        ];
      case 6:
        return const [
          {'title': 'Дневник вместо оценок', 'text': 'Оценки и дневник объединены. Оставляем один понятный раздел — дневник игрока.'},
          {'title': 'Календарь записей', 'text': 'Даты с записями подсвечиваются, выбор дня фильтрует историю.'},
          {'title': 'Что смотреть', 'text': 'Оценивайте самочувствие, заметки игрока и связь с тренировочной нагрузкой.'},
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
        border: Border.all(color: _AppColors.cmrBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle, border: Border.all(color: _AppColors.cmrBorder)),
            child: Center(child: Text('$number', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _cmrTitleText(context, mobile: 13.5, wide: 15.0, color: const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(text, style: _cmrBodyText(context, mobile: 12.2, wide: 13.2, color: const Color(0xFF64748B), weight: FontWeight.w700, height: 1.35)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _AppColors.cmrBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          _buildCmrSectionBadge(tab: tab),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.title == 'Общие' ? 'Профиль игрока' : tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: _fontFamily, fontSize: compact ? 19 : 23, fontWeight: FontWeight.w900, color: const Color(0xFF111827)),
                ),
                const SizedBox(height: 3),
                Text(
                  team.isEmpty ? tab.subtitle : '$team • ${tab.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF64748B), fontSize: compact ? 12 : 13.4, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.edit_outlined, label: 'Профиль', onTap: _openPlayerEditorPanel),
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.chat_bubble_outline_rounded, label: 'Написать', onTap: _openPrivateChat),
            const SizedBox(width: 10),
            _buildCmrHeaderAction(icon: Icons.event_available_outlined, label: 'Тренировка', onTap: _assignTraining),
          ],
          const SizedBox(width: 10),
          _buildCmrIconButton(
            icon: _designLoading ? Icons.sync_rounded : Icons.refresh_rounded,
            onTap: _refreshCmrProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildCmrSectionBadge({required _CategoryTab tab}) {
    final accent = _cmrTabAccent(tab.index);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _cmrTabSoft(tab.index),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(.14)),
      ),
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: _AppColors.softFor(accent),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.76),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: accent.withOpacity(.10)),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionHint(label),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 9.3,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
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
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FAF5),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(.045), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          _buildPhotoPreviewTap(
            imageUrl: photo,
            child: _buildCircleNetworkImage(
              imageUrl: photo,
              size: compact ? 72 : 92,
              borderColor: _AppColors.cmrBorder,
              borderWidth: 2,
              fallback: const Icon(Icons.person_rounded, color: _AppColors.primaryGreen),
            ),
          ),
          SizedBox(width: compact ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF0F172A), fontSize: compact ? 20 : 26, height: 1.05, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCmrDarkChip(position.isEmpty ? 'Амплуа не указано' : position),
                    _buildCmrDarkChip(number.isEmpty ? '№ —' : '№ $number'),
                    _buildCmrDarkChip(age.isEmpty ? 'Возраст —' : '$age лет'),
                    if (team.isNotEmpty) _buildCmrDarkChip(team),
                  ],
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 16),
            Container(
              width: 118,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(
                children: [
                  Text('$readiness%', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('заполнено', style: TextStyle(color: _AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCmrDarkChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF2FA86B), fontSize: 12, fontWeight: FontWeight.w800)),
    );
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
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      padding: EdgeInsets.all(collapsed ? 9 : 12),
      decoration: BoxDecoration(color: _AppColors.cmrSoftPanel, borderRadius: BorderRadius.circular(collapsed ? 18 : 22), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(collapsed ? .014 : .02), blurRadius: collapsed ? 10 : 16, offset: Offset(0, collapsed ? 4 : 7))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _buildPhotoPreviewTap(imageUrl: photo, child: _buildCircleNetworkImage(imageUrl: photo, size: avatarSize, borderColor: Colors.white, borderWidth: 2, fallback: const Icon(Icons.person_rounded, color: _AppColors.primaryGreen))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: collapsed ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontFamily, color: const Color(0xFF101828), fontSize: titleSize, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -.2)),
          SizedBox(height: collapsed ? 3 : 5),
          Text(meta.isEmpty ? 'Амплуа не указано' : meta, maxLines: collapsed ? 1 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF667085), fontSize: 11.3, height: 1.25, fontWeight: FontWeight.w600)),
          if (!collapsed) ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _buildCmrMobileAction(icon: Icons.chat_bubble_outline_rounded, label: 'Написать', onTap: _openPrivateChat)),
              const SizedBox(width: 7),
              Expanded(child: _buildCmrMobileAction(icon: Icons.event_available_outlined, label: 'Тренировка', onTap: _assignTraining)),
            ]),
          ],
        ])),
      ]),
    );
  }


  Widget _buildCmrMobileAction({required IconData icon, required String label, required VoidCallback onTap}) {
    final accent = _actionAccent(icon, label);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _AppColors.softFor(accent),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(.15)),
          boxShadow: [BoxShadow(color: accent.withOpacity(.055), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _isDesktopOrTablet(context) ? 42 : 28,
              height: _isDesktopOrTablet(context) ? 42 : 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.78),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 15, color: accent),
            ),
            SizedBox(width: _isDesktopOrTablet(context) ? 12 : 7),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _actionHint(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: accent, fontSize: 8.8, height: 1, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: Color(0xFF111827), fontSize: 11.2, height: 1, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmrMobileActiveHint() {
    final tab = _categoryTabs.firstWhere(
      (e) => e.index == _selectedTabIndex,
      orElse: () => _categoryTabs.first,
    );
    final accent = _cmrTabAccent(tab.index);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _cmrTabSoft(tab.index),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(tab.icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Раздел открыт ниже. Листайте экран, чтобы смотреть данные.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.8,
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

  Widget _buildCmrMobileBottomMenu() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF101828).withOpacity(0.030), blurRadius: 18, offset: const Offset(0, 8))]),
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
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            onTap: _handleCmrMobileBottomTap,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Обзор'),
              BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'Метрики'),
              BottomNavigationBarItem(icon: Icon(Icons.military_tech_rounded), label: 'Достижения'),
              BottomNavigationBarItem(icon: Icon(Icons.medical_information_rounded), label: 'Медкарта'),
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
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _handleCmrMobileBottomTap(int index) async {
    if (index == 0) {
      if (mounted) setState(() => _selectedTabIndex = 0);
      return;
    }

    if (index == 4) {
      await _openCmrMobileMoreSheet();
      return;
    }

    final tab = _categoryTabs[index];
    await _openCmrMobileTabSheet(tab);
  }

  Future<void> _openCmrMobileMoreSheet() async {
    final items = <_PlayerMobileMoreSheetItem>[
      _PlayerMobileMoreSheetItem.fromTab(_categoryTabs[4], accent: _AppColors.primaryGreen), // Тренировки
      _PlayerMobileMoreSheetItem.fromTab(_categoryTabs[5], accent: _AppColors.orange), // Матчи
      _PlayerMobileMoreSheetItem.fromTab(_categoryTabs[6], accent: _AppColors.teal), // Дневник
      _PlayerMobileMoreSheetItem.fromTab(_categoryTabs[7], accent: _AppColors.purple), // Тестирование
      _PlayerMobileMoreSheetItem.fromTab(_categoryTabs[8], accent: _AppColors.blue), // Экспорт
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
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
                    border: Border.all(color: _AppColors.cmrBorder.withOpacity(.9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
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
                                fontSize: 16,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
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
        border: Border.all(color: _AppColors.cmrBorder.withOpacity(.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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
                    fontSize: 17,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teamName.trim().isEmpty ? 'Профиль игрока и разделы анализа' : 'Команда: $teamName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 12,
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
                        fontSize: 15,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.textSecondary,
                        fontSize: 12,
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
        return 'Метрика';
      case 2:
        return 'Достижение';
      case 3:
        return 'Запись';
      case 4:
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
        return _showEditMetricsDialog;
      case 2:
        return _showEditAchievementsDialog;
      case 3:
        return _showAddMedicalRecordDialog;
      case 4:
        return _assignTraining;
      default:
        return null;
    }
  }

  IconData _sectionFabIcon(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return Icons.add_chart_rounded;
      case 2:
        return Icons.emoji_events_rounded;
      case 3:
        return Icons.add_rounded;
      case 4:
        return Icons.add_task_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  String _sectionFabLabel(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return 'Добавить метрику';
      case 2:
        return 'Добавить достижение';
      case 3:
        return 'Добавить запись';
      case 4:
        return 'Назначить тренировку';
      default:
        return 'Добавить';
    }
  }

  Future<void> _openCmrTabletTabSheet(_CategoryTab tab) async {
    if (!mounted) return;

    if (tab.index == 6 && diaryItems.isEmpty && !diaryLoading) {
      await _loadDiary();
    }
    if (tab.index == 7 && playerTestingSessions.isEmpty && !playerTestingLoading) {
      await _loadPlayerTestingHistory(force: false);
    }
    if (tab.index == 5 && matches.isEmpty && !matchesLoading) {
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
        final dialogWidth = size.width >= 1180 ? 1040.0 : size.width * .86;
        final dialogHeight = size.height >= 860 ? 760.0 : size.height * .86;

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
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: _AppColors.cmrBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _cmrTabSoft(tab.index),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accent.withOpacity(.14)),
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
                                      color: Color(0xFF111827),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    tab.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12.5,
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
                              color: const Color(0xFF64748B),
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

    if (tab.index == 6 && diaryItems.isEmpty && !diaryLoading) {
      await _loadDiary();
    }
    if (tab.index == 7 && playerTestingSessions.isEmpty && !playerTestingLoading) {
      await _loadPlayerTestingHistory(force: false);
    }
    if (tab.index == 5 && matches.isEmpty && !matchesLoading) {
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
          heightFactor: .96,
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
                            border: Border.all(color: _cmrTabAccent(tab.index).withOpacity(.14)),
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
                                style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tab.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: const Color(0xFF64748B),
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


  Widget _buildCmrDesktopWindow({required bool compact}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 1240 : 1500),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF101828).withOpacity(.055),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildCmrWindowHeader(compact: compact),
                _buildCmrWindowTabs(compact: compact),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 10, compact ? 10 : 14, compact ? 10 : 14),
                    child: _buildCmrTabletWorkspace(compact: compact),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrWindowHeader({required bool compact}) {
    final photo = _normalizeImage(widget.player['photo']) ?? '';
    final name = _cmrFullName();
    final team = _playerClub().isEmpty
        ? _firstNotEmpty([widget.player['team_name'], widget.player['teamName']])
        : _playerClub();
    final position = _firstNotEmpty([widget.player['position'], widget.player['role'], widget.player['amplua']]);
    final tab = _categoryTabs.firstWhere((e) => e.index == _selectedTabIndex, orElse: () => _categoryTabs.first);

    return Container(
      height: compact ? 76 : 82,
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 10, compact ? 12 : 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          _buildCmrWindowControls(),
          SizedBox(width: compact ? 12 : 16),
          _buildPhotoPreviewTap(
            imageUrl: photo,
            child: _buildCircleNetworkImage(
              imageUrl: photo,
              size: compact ? 46 : 50,
              borderWidth: 0,
              borderColor: Colors.transparent,
              fallback: const Icon(Icons.person_rounded, color: _AppColors.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF101828),
                    fontSize: compact ? 17 : 19,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.isEmpty ? 'Профиль игрока' : team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF667085),
                          fontSize: compact ? 11.5 : 12.2,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (position.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          position,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.primaryGreen,
                            fontSize: 10.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!compact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, color: const Color(0xFF344054), size: 17),
                  const SizedBox(width: 7),
                  Text(
                    tab.title,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          _buildCmrWindowIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить профиль',
            onTap: _refreshCmrProfile,
          ),
          const SizedBox(width: 8),
          _buildCmrWindowIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Редактировать игрока',
            onTap: _openPlayerEditorPanel,
          ),
          const SizedBox(width: 8),
          _buildCmrWindowIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Закрыть профиль',
            onTap: _closePlayerProfileScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCmrWindowControls() {
    Widget dot(Color color) => Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(const Color(0xFFFF5F57)),
        const SizedBox(width: 7),
        dot(const Color(0xFFFFBD2E)),
        const SizedBox(width: 7),
        dot(const Color(0xFF28C840)),
      ],
    );
  }

  Widget _buildCmrWindowIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 19, color: const Color(0xFF475467)),
          ),
        ),
      ),
    );
  }

  Widget _buildCmrWindowTabs({required bool compact}) {
    return Container(
      height: compact ? 58 : 64,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 4, compact ? 12 : 18, 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _categoryTabs.map((tab) {
            final active = tab.index == _selectedTabIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCmrWindowTabButton(
                tab: tab,
                active: active,
                compact: compact,
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildCmrWindowTabButton({
    required _CategoryTab tab,
    required bool active,
    required bool compact,
  }) {
    final accent = _cmrTabAccent(tab.index);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectCmrTab(tab.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          height: compact ? 40 : 44,
          padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 16),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF344054) : const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF101828).withOpacity(.10),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? _AppColors.primaryGreen : accent.withOpacity(.45),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Icon(tab.icon, size: compact ? 17 : 18, color: active ? Colors.white : const Color(0xFF475467)),
              const SizedBox(width: 7),
              Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF101828),
                  fontSize: compact ? 12.5 : 13.2,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 720;
    final compact = width < 980;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        bottom: isTablet,
        child: isTablet
            ? _buildCmrDesktopWindow(compact: compact)
            : Column(
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
      bottomNavigationBar: isTablet ? null : _buildCmrMobileBottomMenu(),
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
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(.22)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.24),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
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
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(.20)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _AppColors.cmrBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF2563EB)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
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
        border: Border.all(color: _AppColors.cmrBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF178A45),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
