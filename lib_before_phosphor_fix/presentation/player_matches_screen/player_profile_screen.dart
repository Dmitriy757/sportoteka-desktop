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

// =============================
// БАЗОВЫЕ ЦВЕТА (fallback)
// =============================
class _AppColors {
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGradientStart = Color(0xFF00E676);
  static const Color primaryGradientEnd = Color(0xFF00BFA5);
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color white = Colors.white;
  static const Color surfaceLight = Color(0xFFF1F5F9);
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
      headerRadius: 24,
      cardRadius: 18,
      avatarSize: 70,
      titleFontSize: 20,
      bodyFontSize: 14,
      primaryColorValue: 0xFF00C853,
      secondaryColorValue: 0xFF00BFA5,
      backgroundColorValue: 0xFFF8FAFC,
      cardColorValue: 0xFFFFFFFF,
      textPrimaryColorValue: 0xFF1E293B,
      textSecondaryColorValue: 0xFF64748B,
      sectionOrder: ['main_info', 'club_info', 'bio_info'],
      showQuickActions: true,
      showClubCard: true,
      showBioCard: true,
      useHeaderGradient: true,
    );
  }

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);
  Color get backgroundColor => Color(backgroundColorValue);
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
          (json['primaryColorValue'] as num?)?.toInt() ?? 0xFF00C853,
      secondaryColorValue:
          (json['secondaryColorValue'] as num?)?.toInt() ?? 0xFF00BFA5,
      backgroundColorValue:
          (json['backgroundColorValue'] as num?)?.toInt() ?? 0xFFF8FAFC,
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
      useHeaderGradient: json['useHeaderGradient'] ?? true,
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

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design
  _PlayerProfileDesign _design = _PlayerProfileDesign.defaults();
  bool _designLoading = false;
  bool _designSaving = false;
  int _trainerUserId = 0;

  final List<_CategoryTab> _categoryTabs = const [
    _CategoryTab(
        0, "Общие", "Основная информация", Icons.person_outline_rounded),
    _CategoryTab(
        1, "Метрики", "Спортивные показатели", Icons.show_chart_rounded),
    _CategoryTab(
        2, "Достижения", "Награды и медиа", Icons.military_tech_rounded),
    _CategoryTab(
        3, "Медкарта", "Медицинские записи", Icons.medical_information_rounded),
    _CategoryTab(
        4, "Тренировки", "PRO / История", Icons.sports_soccer_rounded),
    _CategoryTab(5, "Матчи", "Игровая история", Icons.emoji_events_rounded),
    _CategoryTab(6, "Дневник", "Самооценка игрока", Icons.menu_book_rounded),
  ];

  // helpers
  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  Color get _primary => _design.primaryColor;
  Color get _secondary => _design.secondaryColor;
  Color get _bg => _design.backgroundColor;
  Color get _card => _design.cardColor;
  Color get _textPrimary => _design.textPrimaryColor;
  Color get _textSecondary => _design.textSecondaryColor;

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
    await _loadDesignFromServer();
    if (mounted) setState(() {});
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
    final playerUserId = _asInt(widget.player["user_id"]);
    if (_trainerUserId <= 0 || playerUserId <= 0) return;

    setState(() => _designLoading = true);

    try {
      final uri = Uri.parse(
        '$_apiBase/get_player_profile_design.php'
        '?trainer_user_id=$_trainerUserId'
        '&player_user_id=$playerUserId',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is Map && data['success'] == true && data['design'] != null) {
        final raw = data['design'];
        if (raw is Map<String, dynamic>) {
          _design = _PlayerProfileDesign.fromJson(raw);
        } else if (raw is Map) {
          _design =
              _PlayerProfileDesign.fromJson(Map<String, dynamic>.from(raw));
        }
      }
    } catch (e) {
      debugPrint('Error loading player design: $e');
    } finally {
      if (mounted) setState(() => _designLoading = false);
    }
  }

  Future<void> _saveDesignToServer() async {
    final playerUserId = _asInt(widget.player["user_id"]);
    final playerId = _asInt(widget.player["id"] ?? widget.player["player_id"]);
    final teamId = _asInt(widget.player["team_id"]);

    if (_trainerUserId <= 0 || playerUserId <= 0) return;

    setState(() => _designSaving = true);

    try {
      final uri = Uri.parse('$_apiBase/save_player_profile_design.php');
      final res = await http.post(
        uri,
        body: {
          'trainer_user_id': '$_trainerUserId',
          'player_user_id': '$playerUserId',
          'player_id': '$playerId',
          'team_id': '$teamId',
          'design_json': jsonEncode(_design.toJson()),
        },
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      if (!(data is Map && data['success'] == true)) {
        throw data is Map
            ? (data['message'] ?? 'Ошибка сохранения дизайна').toString()
            : 'Ошибка сохранения дизайна';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дизайн профиля сохранён')),
      );
    } catch (e) {
      debugPrint('Error saving player design: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) setState(() => _designSaving = false);
    }
  }

  void _openDesignEditor() {
    final colorPresets = <Color>[
      const Color(0xFF00C853),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF0F172A),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        _PlayerProfileDesign temp = _design;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget colorPickerRow({
              required String title,
              required Color selected,
              required ValueChanged<Color> onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle(size: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorPresets.map((c) {
                      final active = c.value == selected.value;
                      return GestureDetector(
                        onTap: () => setModalState(() => onChanged(c)),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: active
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            Widget sliderTile({
              required String title,
              required double value,
              required double min,
              required double max,
              required ValueChanged<double> onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$title: ${value.toStringAsFixed(0)}",
                    style: _bodyStyle(size: 13, color: _textPrimary),
                  ),
                  Slider(
                    value: value,
                    min: min,
                    max: max,
                    activeColor: temp.primaryColor,
                    onChanged: (v) => setModalState(() => onChanged(v)),
                  ),
                ],
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Редактор дизайна игрока",
                              style: _titleStyle(size: 18),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                temp = _PlayerProfileDesign.defaults();
                              });
                            },
                            child: const Text("Сброс"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            colorPickerRow(
                              title: "Основной цвет",
                              selected: temp.primaryColor,
                              onChanged: (c) => temp = temp.copyWith(
                                primaryColorValue: c.value,
                              ),
                            ),
                            const SizedBox(height: 16),
                            colorPickerRow(
                              title: "Второй цвет",
                              selected: temp.secondaryColor,
                              onChanged: (c) => temp = temp.copyWith(
                                secondaryColorValue: c.value,
                              ),
                            ),
                            const SizedBox(height: 16),
                            colorPickerRow(
                              title: "Фон экрана",
                              selected: temp.backgroundColor,
                              onChanged: (c) => temp = temp.copyWith(
                                backgroundColorValue: c.withOpacity(0.12).value,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("Шрифт", style: _titleStyle(size: 14)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text("Default"),
                                  selected: temp.fontFamily == 'default',
                                  onSelected: (_) => setModalState(() {
                                    temp = temp.copyWith(fontFamily: 'default');
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text("Inter"),
                                  selected: temp.fontFamily == 'inter',
                                  onSelected: (_) => setModalState(() {
                                    temp = temp.copyWith(fontFamily: 'inter');
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text("Montserrat"),
                                  selected: temp.fontFamily == 'montserrat',
                                  onSelected: (_) => setModalState(() {
                                    temp =
                                        temp.copyWith(fontFamily: 'montserrat');
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text("Roboto"),
                                  selected: temp.fontFamily == 'roboto',
                                  onSelected: (_) => setModalState(() {
                                    temp = temp.copyWith(fontFamily: 'roboto');
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              value: temp.useHeaderGradient,
                              onChanged: (v) => setModalState(() {
                                temp = temp.copyWith(useHeaderGradient: v);
                              }),
                              title: const Text("Градиент в шапке"),
                            ),
                            SwitchListTile(
                              value: temp.showQuickActions,
                              onChanged: (v) => setModalState(() {
                                temp = temp.copyWith(showQuickActions: v);
                              }),
                              title: const Text("Быстрые кнопки"),
                            ),
                            SwitchListTile(
                              value: temp.showClubCard,
                              onChanged: (v) => setModalState(() {
                                temp = temp.copyWith(showClubCard: v);
                              }),
                              title: const Text("Блок клуба"),
                            ),
                            SwitchListTile(
                              value: temp.showBioCard,
                              onChanged: (v) => setModalState(() {
                                temp = temp.copyWith(showBioCard: v);
                              }),
                              title: const Text("Блок “О игроке”"),
                            ),
                            const SizedBox(height: 8),
                            sliderTile(
                              title: "Скругление шапки",
                              value: temp.headerRadius,
                              min: 0,
                              max: 40,
                              onChanged: (v) =>
                                  temp = temp.copyWith(headerRadius: v),
                            ),
                            sliderTile(
                              title: "Скругление карточек",
                              value: temp.cardRadius,
                              min: 8,
                              max: 32,
                              onChanged: (v) =>
                                  temp = temp.copyWith(cardRadius: v),
                            ),
                            sliderTile(
                              title: "Размер аватара",
                              value: temp.avatarSize,
                              min: 56,
                              max: 120,
                              onChanged: (v) =>
                                  temp = temp.copyWith(avatarSize: v),
                            ),
                            sliderTile(
                              title: "Заголовок",
                              value: temp.titleFontSize,
                              min: 16,
                              max: 28,
                              onChanged: (v) =>
                                  temp = temp.copyWith(titleFontSize: v),
                            ),
                            sliderTile(
                              title: "Основной текст",
                              value: temp.bodyFontSize,
                              min: 11,
                              max: 18,
                              onChanged: (v) =>
                                  temp = temp.copyWith(bodyFontSize: v),
                            ),
                            const SizedBox(height: 16),
                            Text("Порядок секций",
                                style: _titleStyle(size: 14)),
                            const SizedBox(height: 8),
                            _buildSectionReorderEditor(
                              temp.sectionOrder,
                              onChanged: (newOrder) {
                                setModalState(() {
                                  temp = temp.copyWith(sectionOrder: newOrder);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _designSaving
                              ? null
                              : () async {
                                  setState(() => _design = temp);
                                  await _saveDesignToServer();
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                },
                          icon: _designSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _designSaving
                                ? "Сохраняем..."
                                : "Сохранить дизайн",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: temp.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
      },
    );
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
              color: const Color(0xFFF8FAFC),
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
      final teamId = _asInt(widget.player["team_id"]);
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
    final raw = _asStr(e["date"] ?? e["start_at"] ?? e["day"]).trim();
    if (raw.isEmpty) return null;

    final tryIso = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (tryIso != null) return tryIso;

    try {
      return DateFormat('dd.MM.yyyy').parse(raw);
    } catch (_) {
      return null;
    }
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

  Future<void> _loadPlayerTrainingHistory({bool force = false}) async {
    if (eventsLoading) return;
    if (!force && teamEvents.isNotEmpty) return;

    setState(() {
      eventsLoading = true;
      eventsError = null;
    });

    try {
      final teamId = _asInt(widget.player["team_id"]);
      if (teamId <= 0) throw "team_id is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final now = DateTime.now();
      final from = _eventFilterDate != null
          ? _eventFilterDate!
          : DateTime(now.year, now.month, 1);
      final to = _eventFilterDate != null
          ? _eventFilterDate!
          : DateTime(now.year, now.month + 1, 0);

      final url = Uri.parse(
        "$_apiBase/get_player_training_history.php"
        "?team_id=$teamId"
        "&player_id=$playerId"
        "&from=${DateFormat('yyyy-MM-dd').format(from)}"
        "&to=${DateFormat('yyyy-MM-dd').format(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки истории тренировок")
                : "Ошибка загрузки истории тренировок")
            .toString();
      }

      final raw = (data["items"] ?? []) as List;
      final list = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

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

  Future<void> _loadPlayerInfoForEvent(int eventId) async {
    setState(() => selectedEventPlayerInfo = null);

    try {
      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final url = Uri.parse(
          "$_apiBase/get_player_event_info.php?event_id=$eventId&player_id=$playerId");
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки оценки")
                : "Ошибка загрузки оценки")
            .toString();
      }

      final info = Map<String, dynamic>.from(data["info"] ?? {});

      final fallbackRating =
          _asInt((selectedEvent?["player_rating"] ?? selectedEvent?["rating"] ?? 0));
      if ((info["player_rating"] ?? info["rating"]) == null &&
          fallbackRating > 0) {
        info["player_rating"] = fallbackRating;
      }

      if (!mounted) return;
      setState(() => selectedEventPlayerInfo = info);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        selectedEventPlayerInfo = {"error": e.toString()};
      });
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
      final teamId = _asInt(widget.player["team_id"]);
      if (teamId <= 0) throw "team_id is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);

      final url = Uri.parse(
        "$_apiBase/get_player_attendance_log.php"
        "?team_id=$teamId"
        "&player_id=$playerId"
        "&from=${DateFormat('yyyy-MM-dd').format(from)}"
        "&to=${DateFormat('yyyy-MM-dd').format(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));

      final body = res.body.trim();
      debugPrint("ATTENDANCE URL: $url");
      debugPrint("ATTENDANCE STATUS: ${res.statusCode}");
      debugPrint("ATTENDANCE RAW: '$body'");

      if (body.isEmpty) {
        throw "Сервер вернул пустой ответ";
      }

      final data = jsonDecode(body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки посещений")
                : "Ошибка загрузки посещений")
            .toString();
      }

      final dynamic rawItems = data["items"] ?? [];

      List<Map<String, dynamic>> list = [];

      if (rawItems is List) {
        list = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (rawItems is Map) {
        list = rawItems.entries.map((entry) {
          final value = Map<String, dynamic>.from(entry.value);
          return {
            "event_id": 0,
            "title": "",
            "date": "",
            ...value,
          };
        }).toList();
      }

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

  void _openCoachNoteSheet() async {
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
                    color: const Color(0xFFF3F5F8),
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
      final teamId = _asInt(widget.player["team_id"]);
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
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map
                ? (data["message"] ?? "Ошибка загрузки календаря")
                : "Ошибка загрузки календаря")
            .toString();
      }

      final raw = (data["items"] ?? []) as List;
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

 Future<void> _loadMatches({bool force = false}) async {
  if (matchesLoading) return;
  if (!force && matches.isNotEmpty) return;

  setState(() {
    matchesLoading = true;
    matchesError = null;
  });

  try {
    final teamId = _asInt(widget.player["team_id"]);
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

  // =============================
  // HEADER
  // =============================
  Widget _buildHeader() {
    final photo = _normalizeImage(widget.player["photo"]);
    final fullName =
        (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок")
            .toString();
    final position =
        (widget.player["position"] ?? "Позиция не указана").toString();
    final jerseyNumber = (widget.player["jersey_number"] ?? '-').toString();
    final club = _playerClub().isNotEmpty ? _playerClub() : "Клуб не указан";
    final age = _playerAge().isNotEmpty ? _playerAge() : "-";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _design.useHeaderGradient
              ? [
                  _primary.withOpacity(0.95),
                  _secondary.withOpacity(0.85),
                  _secondary.withOpacity(0.70),
                ]
              : [
                  _primary,
                  _primary,
                ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_design.headerRadius),
          bottomRight: Radius.circular(_design.headerRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCircleNetworkImage(
                imageUrl: photo,
                size: _design.avatarSize,
                borderColor: Colors.white,
                borderWidth: 2.5,
                glow: Colors.white.withOpacity(0.5),
                fallback: Container(
                  color: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 35),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: _titleStyle(
                        size: _design.titleFontSize,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        position,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 18),
                  onPressed: () =>
                      Get.toNamed(AppRoutes.editPlayerScreen, arguments: widget.player),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactInfoChip(
                  icon: Icons.sports_soccer_rounded,
                  label: "Номер",
                  value: "#$jerseyNumber",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactInfoChip(
                  icon: Icons.group_rounded,
                  label: "Клуб",
                  value: club,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactInfoChip(
                  icon: Icons.cake_rounded,
                  label: "Возраст",
                  value: "$age лет",
                ),
              ),
            ],
          ),
          if (_design.showQuickActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildCompactActionChip(
                    icon: Icons.chat_rounded,
                    label: "Чат",
                    onTap: _openPrivateChat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactActionChip(
                    icon: Icons.fitness_center_rounded,
                    label: "Тренировка",
                    onTap: _assignTraining,
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primary, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // TABS
  // =============================
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_categoryTabs.length, (i) {
            final tab = _categoryTabs[i];
            final isActive = tab.index == _selectedTabIndex;

            return Container(
              margin: const EdgeInsets.only(right: 8),
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
                      if (_trainingSubTab == 0) {
                        await _loadPlayerTrainingHistory(force: true);
                      }
                      if (_trainingSubTab == 1) {
                        await _loadAttendanceLog(force: true);
                      }
                      await _loadTeamCalendar(force: false);
                    }

                    if (tab.index == 5) {
                      await _loadMatches();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: isActive
                          ? LinearGradient(
                              colors: [_primary, _secondary],
                            )
                          : null,
                      color: isActive ? null : _card,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: _primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          color: isActive ? Colors.white : _primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.title,
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontWeight: FontWeight.w900,
                            color: isActive ? Colors.white : _textPrimary,
                            fontSize: 13,
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
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildGeneralTab(),
          _buildMetricsTab(),
          _buildAchievementsTab(),
          _buildMedicalTab(),
          _buildTrainingTab(),
          _buildMatchesTab(),
          _buildDiaryTab(),
        ],
      ),
    );
  }

  // =============================
  // ОБЩИЕ
  // =============================
  Widget _buildGeneralTab() {
    final sections = <String, Widget>{
      'main_info': _buildMainInfoSection(),
      if (_design.showClubCard) 'club_info': _buildClubInfoSection(),
      if (_design.showBioCard) 'bio_info': _buildBioInfoSection(),
    };

    final visibleOrder = _design.sectionOrder.where((id) {
      if (id == 'club_info' && !_design.showClubCard) return false;
      if (id == 'bio_info' && !_design.showBioCard) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final id in visibleOrder) ...[
          if (sections[id] != null) sections[id]!,
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMainInfoSection() {
    final age = _playerAge();
    final birthDate = _playerBirthDate();
    final nationality = _firstNotEmpty([
      widget.player["nationality"],
      widget.player["country"],
      widget.player["citizenship"],
    ]);
    final position = _firstNotEmpty([
      widget.player["position"],
      widget.player["player_position"],
    ]);
    final jerseyNumber = _firstNotEmpty([
      widget.player["jersey_number"],
      widget.player["number"],
      widget.player["player_number"],
    ]);
    final height = _firstNotEmpty([
      widget.player["height"],
      widget.player["player_height"],
    ]);
    final weight = _firstNotEmpty([
      widget.player["weight"],
      widget.player["player_weight"],
    ]);
    final foot = _firstNotEmpty([
      widget.player["foot"],
      widget.player["preferred_foot"],
    ]);

    return _buildStyledSectionCard(
      title: "Основная информация",
      icon: Icons.person_outline_rounded,
      child: _buildInfoGrid([
        _InfoItem(
            icon: Icons.cake_rounded,
            label: "Возраст",
            value: age.isNotEmpty ? "$age лет" : "-"),
        _InfoItem(
            icon: Icons.calendar_today_rounded,
            label: "Дата рождения",
            value: birthDate.isNotEmpty ? birthDate : "-"),
        _InfoItem(
            icon: Icons.flag_rounded,
            label: "Гражданство",
            value: nationality.isNotEmpty ? nationality : "-"),
        _InfoItem(
            icon: Icons.sports_soccer_rounded,
            label: "Позиция",
            value: position.isNotEmpty ? position : "-"),
        _InfoItem(
            icon: Icons.format_list_numbered_rounded,
            label: "Номер",
            value: jerseyNumber.isNotEmpty ? "#$jerseyNumber" : "-"),
        _InfoItem(
            icon: Icons.height_rounded,
            label: "Рост",
            value: height.isNotEmpty ? "$height см" : "-"),
        _InfoItem(
            icon: Icons.monitor_weight_rounded,
            label: "Вес",
            value: weight.isNotEmpty ? "$weight кг" : "-"),
        _InfoItem(
            icon: Icons.directions_run_rounded,
            label: "Нога",
            value: foot.isNotEmpty ? foot : "-"),
      ]),
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
      title: "О игроке",
      icon: Icons.info_outline_rounded,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withOpacity(0.10)),
        ),
        child: Text(
          bio,
          style: _bodyStyle(
            size: _design.bodyFontSize,
            color: _textPrimary,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Row(
          children: [
            Icon(item.icon, size: 14, color: _primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: _titleStyle(size: 16, color: _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // =============================
  // МЕТРИКИ
  // =============================
  Widget _buildMetricsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Спортивные показатели",
          subtitle: "Текущие метрики игрока",
          icon: Icons.show_chart_rounded,
          count: metrics.length,
        ),
        const SizedBox(height: 16),
        if (metrics.isEmpty)
          _buildEmptyState(
            icon: Icons.analytics_outlined,
            message: "Нет данных о метриках",
          )
        else
          ...metrics.map((metric) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMetricCard(metric),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildMetricCard(String metric) {
    final parts = metric.split(':');
    if (parts.length < 2) return const SizedBox();

    double? progress;
    try {
      final value = double.tryParse(
          parts[1].trim().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (value != null && value <= 100) {
        progress = value / 100;
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, _secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  parts[0].trim().toLowerCase().contains('скорость')
                      ? Icons.speed_rounded
                      : parts[0].trim().toLowerCase().contains('сила')
                          ? Icons.fitness_center_rounded
                          : parts[0].trim().toLowerCase().contains('выносливость')
                              ? Icons.timer_rounded
                              : Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parts[0].trim(),
                      style: _titleStyle(size: 16, color: _textPrimary),
                    ),
                    const SizedBox(height: 4),
                    if (progress != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: _AppColors.surfaceLight,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_primary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      parts.sublist(1).join(':').trim(),
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =============================
  // ДОСТИЖЕНИЯ
  // =============================
  Widget _buildAchievementsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          title: "Достижения",
          icon: Icons.military_tech_rounded,
          children: [
            Text(
              _asStr(widget.player["achievements"]).isNotEmpty
                  ? _asStr(widget.player["achievements"])
                  : "Нет достижений",
              style: _bodyStyle(size: 14, color: _textSecondary, weight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionBanner(
          title: "Медиа",
          subtitle: "Фото и видео материалы",
          icon: Icons.collections_rounded,
          count: mediaLinks.length,
        ),
        const SizedBox(height: 16),
        if (mediaLinks.isEmpty)
          _buildEmptyState(
            icon: Icons.photo_camera_back_rounded,
            message: "Нет медиа материалов",
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mediaLinks.map(_buildMediaItem).toList(),
          ),
      ],
    );
  }

  Widget _buildMediaItem(String url) {
    final isImage = url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png');
    final isVideo =
        url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.mov');

    final norm = _normalizeImage(url) ?? url;

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(norm),
          mode: LaunchMode.externalApplication),
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 3,
        height: (MediaQuery.of(context).size.width - 48) / 3,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          image: isImage
              ? DecorationImage(
                  image: NetworkImage(norm),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: isVideo
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // =============================
  // МЕДКАРТА
  // =============================
  Widget _buildMedicalTab() {
    if (isLoading) {
      return Center(
          child: CircularProgressIndicator(color: _primary));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildAddButton(),
        ),
        _buildSectionBanner(
          title: "Медицинская карта",
          subtitle: "История записей",
          icon: Icons.medical_information_rounded,
          count: medicalRecords.length,
        ),
        const SizedBox(height: 16),
        if (medicalRecords.isEmpty)
          _buildEmptyState(
            icon: Icons.medical_services_rounded,
            message: "Нет медицинских записей",
            action: TextButton(
              onPressed: _showAddMedicalRecordDialog,
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text("Добавить запись"),
            ),
          )
        else
          ...medicalRecords.map((record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMedicalRecordCard(record),
              )),
      ],
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddMedicalRecordDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
        label: Text(
          "Добавить медицинскую запись",
          style: TextStyle(
            fontFamily: _fontFamily,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
    );
  }

 Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(_design.cardRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record['type'] == 'Травма'
                    ? Icons.healing_rounded
                    : record['type'] == 'Осмотр'
                        ? Icons.health_and_safety_rounded
                        : Icons.medical_information_rounded,
                color: _primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (record['type'] ?? 'Запись').toString(),
                    style: _titleStyle(size: 15, color: _textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (record['title'] ?? 'Без названия').toString(),
                    style: _bodyStyle(size: 13, color: _textSecondary, weight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showEditMedicalRecordDialog(record);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: _primary),
                      const SizedBox(width: 6),
                      const Text("Редактировать",
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.more_vert_rounded,
                    size: 18,
                    color: _textSecondary.withOpacity(0.6)),
              ),
            ),
          ],
        ),
        if (record['value'] != null &&
            record['value'].toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              record['value'].toString(),
              style: _bodyStyle(size: 13, color: _textPrimary, weight: FontWeight.w500),
            ),
          ),
        ],
        if (record['comment'] != null &&
            record['comment'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary.withOpacity(0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.comment_rounded, size: 14, color: _textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record['comment'].toString(),
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 12, color: _textSecondary.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              "Дата: ${(record['date'] ?? 'Не указана').toString()}",
              style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
                  color: _textSecondary.withOpacity(0.8),
                  height: 1.2),
            ),
          ],
        ),
        // ============= ЗАМЕНЕННАЯ ЧАСТЬ С ОТОБРАЖЕНИЕМ ФАЙЛА =============
        if (record['file_url'] != null && 
            record['file_url'].toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              final fileUrl = record['file_url'].toString();
              final fullUrl = fileUrl.startsWith('http')
                  ? fileUrl
                  : '$_apiBase/../uploads/medical/$fileUrl';
              
              // Определяем иконку в зависимости от типа файла
              IconData fileIcon;
              if (fileUrl.toLowerCase().endsWith('.pdf')) {
                fileIcon = Icons.picture_as_pdf_rounded;
              } else if (fileUrl.toLowerCase().endsWith('.jpg') ||
                  fileUrl.toLowerCase().endsWith('.jpeg') ||
                  fileUrl.toLowerCase().endsWith('.png') ||
                  fileUrl.toLowerCase().endsWith('.gif')) {
                fileIcon = Icons.image_rounded;
              } else if (fileUrl.toLowerCase().endsWith('.doc') ||
                  fileUrl.toLowerCase().endsWith('.docx')) {
                fileIcon = Icons.description_rounded;
              } else if (fileUrl.toLowerCase().endsWith('.xls') ||
                  fileUrl.toLowerCase().endsWith('.xlsx')) {
                fileIcon = Icons.table_chart_rounded;
              } else {
                fileIcon = Icons.attach_file_rounded;
              }
              
              launchUrl(
                Uri.parse(fullUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: Icon(
              // Определяем иконку для кнопки
              record['file_url'].toString().toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_rounded
                  : record['file_url'].toString().toLowerCase().endsWith('.jpg') ||
                          record['file_url'].toString().toLowerCase().endsWith('.jpeg') ||
                          record['file_url'].toString().toLowerCase().endsWith('.png') ||
                          record['file_url'].toString().toLowerCase().endsWith('.gif')
                      ? Icons.image_rounded
                      : Icons.attach_file_rounded,
              size: 14,
            ),
            label: Text(
              'Просмотреть вложение',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: _primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        // ============= КОНЕЦ ЗАМЕНЕННОЙ ЧАСТИ =============
      ],
    ),
  );
}
  // =============================
  // ТРЕНИРОВКИ
  // =============================
  Widget _buildTrainingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Тренировки PRO",
          subtitle:
              "События, журнал посещения, календарь команды и индивидуальные занятия",
          icon: Icons.sports_soccer_rounded,
          count: 0,
        ),
        const SizedBox(height: 12),
        _buildTrainingSubTabs(),
        const SizedBox(height: 16),
        if (_trainingSubTab == 0) _buildEventsSubTab(),
        if (_trainingSubTab == 1) _buildAttendanceSubTab(),
        if (_trainingSubTab == 2) _buildIndividualSubTab(),
        const SizedBox(height: 14),
        if (_trainingSubTab == 0) _buildTeamCalendarBlock(),
      ],
    );
  }

  Widget _buildTrainingSubTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTrainingTabItem(
            title: "События",
            subtitle: "Поиск, дата, оценки",
            icon: Icons.event_note_rounded,
            index: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTrainingTabItem(
            title: "Журнал",
            subtitle: "Посещаемость, опоздания",
            icon: Icons.fact_check_rounded,
            index: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTrainingTabItem(
            title: "Индивид.",
            subtitle: "Личные тренировки",
            icon: Icons.fitness_center_rounded,
            index: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingTabItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required int index,
  }) {
    final active = _trainingSubTab == index;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        setState(() => _trainingSubTab = index);
        if (index == 0) await _loadPlayerTrainingHistory(force: true);
        if (index == 1) await _loadAttendanceLog(force: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? _primary.withOpacity(0.14) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _primary.withOpacity(0.35) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primary.withOpacity(active ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: _textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 9,
                color: _textSecondary,
                height: 1.2,
              ),
            ),
          ],
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
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });

    await _loadPlayerTrainingHistory(force: true);
  }

  void _clearEventDate() async {
    setState(() {
      _eventFilterDate = null;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });
    await _loadPlayerTrainingHistory(force: true);
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final q = _eventSearchC.text.trim().toLowerCase();
    final dateKey = _eventFilterDate != null
        ? DateFormat('yyyy-MM-dd').format(_eventFilterDate!)
        : null;

    return teamEvents.where((e) {
      final title = _asStr(e["title"]).toLowerCase();
      final date = _asStr(e["date"] ?? e["start_at"] ?? e["day"]).toLowerCase();

      final okQ = q.isEmpty ? true : (title.contains(q) || date.contains(q));
      final okD = dateKey == null ? true : date.contains(dateKey);

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
                  fontSize: 13,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.grey.shade200, height: 1)),
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
                });
                await _loadPlayerInfoForEvent(id);
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
                      width: 44,
                      height: 44,
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
                              fontSize: 13,
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
                              fontSize: 11,
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
                          fontSize: 10,
                          color: rating > 0
                              ? Colors.amber.shade800
                              : _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: _textSecondary),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickEventDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: _primary.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                color: _primary, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _eventDateText(),
                                style: TextStyle(
                                    fontFamily: _fontFamily,
                                    fontWeight: FontWeight.w900,
                                    color: _textPrimary,
                                    fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_eventFilterDate != null)
                              IconButton(
                                onPressed: _clearEventDate,
                                icon: const Icon(Icons.close_rounded, size: 14),
                                color: _textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            else
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16, color: _textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: "Обновить",
                    onPressed: () => _loadPlayerTrainingHistory(force: true),
                    icon:
                        Icon(Icons.refresh_rounded, color: _primary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _eventSearchC,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: "Поиск...",
                    prefixIcon: Icon(Icons.search_rounded, size: 16),
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontFamily: _fontFamily, fontSize: 12),
                ),
              ),
            ],
          ),
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
                  selectedEvent = null;
                  selectedEventPlayerInfo = null;
                });
                _loadPlayerTrainingHistory(force: true);
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

    final status = _asStr(selectedEventPlayerInfo?["status"]);
    final late = _asInt(selectedEventPlayerInfo?["late_minutes"]);
    final reason = _asStr(selectedEventPlayerInfo?["reason"]).trim();

    final playerRating =
        selectedEventPlayerInfo?["player_rating"] ?? selectedEventPlayerInfo?["rating"];
    final coachRating = selectedEventPlayerInfo?["coach_rating"];
    final coachComment = _asStr(selectedEventPlayerInfo?["coach_comment"]).trim();
    final coachNote = _asStr(selectedEventPlayerInfo?["coach_note"]).trim();

    final meta = _statusMeta(status, late);
    final statusText = meta.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(color: _primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
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
              TextButton.icon(
                onPressed: _openCoachNoteSheet,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text("Заметка",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: _primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillInfo(Icons.fact_check_rounded, "Статус", statusText),
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
        return (
          text: "Присутствует",
          color: const Color(0xFF22C55E),
          icon: Icons.check_circle_rounded,
        );
      case "absent":
        return (
          text: "Отсутствует",
          color: const Color(0xFFEF4444),
          icon: Icons.cancel_rounded,
        );
      case "late":
        return (
          text: "Болен",
          color: const Color(0xFFF59E0B),
          icon: Icons.sick_rounded,
        );
      case "injured":
        return (
          text: "Травма",
          color: const Color(0xFF8B5CF6),
          icon: Icons.healing_rounded,
        );
      case "individual":
        return (
          text: "Индивид.",
          color: const Color(0xFF0EA5E9),
          icon: Icons.person_rounded,
        );
      case "dayoff":
        return (
          text: "Выходной",
          color: const Color(0xFF9CA3AF),
          icon: Icons.beach_access_rounded,
        );
      case "unset":
      case "":
      case "none":
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
        attendanceLog.where((x) => _asStr(x["status"]) == "absent").length;
    final sickCount = attendanceLog.where((x) {
      final s = _asStr(x["status"]).trim().toLowerCase();
      return s == "late";
    }).length;
    final injuredCount = attendanceLog.where((x) {
      final s = _asStr(x["status"]).trim().toLowerCase();
      return s == "injured";
    }).length;

    int sumCoach = 0;
    int cntCoach = 0;
    for (final x in attendanceLog) {
      final r = x["coach_rating"];
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
          title: "Календарь активности PRO",
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
            final st = _asStr(x["status"]).trim();
            final lateMin = _asInt(x["late_minutes"]);
            final reason = _asStr(x["reason"]).trim();

            final coachComment = _asStr(x["coach_comment"]).trim();
            final attendanceNote = _asStr(x["note"]).trim();
            final coachNote = _asStr(x["coach_note"]).trim();

            final meta = _statusMeta(st, lateMin);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(_design.cardRadius),
                border: Border.all(color: Colors.grey.shade200),
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
                          color: meta.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(meta.icon, color: meta.color),
                      ),
                      const SizedBox(width: 10),
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
                                fontSize: 13,
                              ),
                            ),
                            if (eventTitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                eventTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              meta.text,
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: meta.color.withOpacity(0.20)),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 18),
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
    return Column(
      children: [
        _buildSectionBanner(
          title: "Индивидуальные тренировки",
          subtitle: "Личные занятия игрока",
          icon: Icons.fitness_center_rounded,
          count: 0,
        ),
        const SizedBox(height: 12),
        TrainingHistoryWidget(playerId: _asInt(widget.player["user_id"])),
      ],
    );
  }

  Widget _buildTeamCalendarBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
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
              color: const Color(0xFFF3F5F8),
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
        color: _card,
        borderRadius: BorderRadius.circular(_design.cardRadius),
        border: Border.all(color: Colors.grey.shade200),
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
                if (type.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
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
    if (matchesLoading) {
      return Center(child: CircularProgressIndicator(color: _primary));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Игровая история (Матчи)",
          subtitle:
              "Соперник • турнир • минуты • голы/ассисты • рейтинг • разбор",
          icon: Icons.emoji_events_rounded,
          count: matches.length,
        ),
        const SizedBox(height: 12),
        if (matchesError != null)
          _buildEmptyState(
              icon: Icons.error_outline_rounded, message: matchesError!)
        else if (matches.isEmpty)
          _buildEmptyState(
            icon: Icons.sports_soccer_rounded,
            message:
                "Матчей пока нет. (Подключим из базы — и появится история.)",
          )
        else
          ...matches.map((m) => _buildMatchCard(m)).toList(),
      ],
    );
  }

 Widget _buildMatchCard(Map<String, dynamic> m) {
  final matchId = _asInt(m["match_id"] ?? m["id"]);
  final opponent = _asStr(m["opponent"]).isEmpty ? "-" : _asStr(m["opponent"]);
  final tournament = _asStr(m["competition_name"]).isEmpty
      ? "-"
      : _asStr(m["competition_name"]);
  final matchDate = _asStr(m["match_date"]).trim();

  final ourScore = _asStr(m["our_score"]).trim();
  final opponentScore = _asStr(m["opponent_score"]).trim();
  final score = (ourScore.isNotEmpty || opponentScore.isNotEmpty)
      ? "$ourScore:$opponentScore"
      : "";

  final video = _asStr(m["video_url"]).trim();
  final coachComment = _asStr(m["notes"]).trim();
  final ttdText = _asStr(m["ttd_text"]).trim();

  final prettyDate = () {
    if (matchDate.isEmpty) return "-";
    final d = DateTime.tryParse(matchDate.replaceAll(' ', 'T'));
    if (d == null) return matchDate;
    return DateFormat('dd.MM.yyyy').format(d);
  }();

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(_design.cardRadius),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
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
                color: _primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.emoji_events_rounded, color: _primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opponent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(size: 14, color: _textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$prettyDate${tournament.isNotEmpty ? " • $tournament" : ""}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(size: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (score.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  score,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        if (ttdText.isNotEmpty) ...[
          const SizedBox(height: 10),
          _noteBox(
            icon: Icons.analytics_outlined,
            title: "ТТД",
            text: ttdText,
          ),
        ],
        if (coachComment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _noteBox(
            icon: Icons.chat_bubble_outline_rounded,
            title: "Комментарий",
            text: coachComment,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: matchId <= 0
                  ? null
                  : () async {
                      final playerId = await _resolvePlayerId();
                      if (!mounted || playerId <= 0) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerMatchDetailScreen(
                            matchId: matchId,
                            playerId: playerId,
                            playerName: _asStr(
                              widget.player["fullName"] ??
                                  widget.player["full_name"] ??
                                  "Игрок",
                            ),
                            opponent: opponent,
                            tournament: tournament,
                            score: score,
                            matchDate: matchDate,
                            videoUrl: video,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.insights_rounded, size: 16),
              label: const Text(
                "Подробнее",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (video.isNotEmpty)
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(video),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                label: const Text(
                  "Видео",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: _primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
  // =============================
  // ДНЕВНИК
  // =============================
  Widget _buildDiaryTab() {
    if (diaryLoading) {
      return Center(child: CircularProgressIndicator(color: _primary));
    }

    if (diaryError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmptyState(
            icon: Icons.error_outline_rounded,
            message: diaryError!,
            action: TextButton(
              onPressed: _loadDiary,
              style: TextButton.styleFrom(foregroundColor: _primary),
              child: const Text("Повторить"),
            ),
          ),
        ],
      );
    }

   
   
    if (diaryItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionBanner(
            title: "Дневник футболиста",
            subtitle: "Оценки и заметки после тренировок",
            icon: Icons.menu_book_rounded,
            count: 0,
          ),
          const SizedBox(height: 16),
          _buildEmptyState(
            icon: Icons.menu_book_rounded,
            message: "Самооценок пока нет. После тренировок игрок будет оставлять оценки — здесь появится история.",
            action: TextButton(
              onPressed: _loadDiary,
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Обновить"),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Дневник футболиста",
          subtitle: "Оценки и заметки после тренировок",
          icon: Icons.menu_book_rounded,
          count: diaryItems.length,
        ),
        const SizedBox(height: 16),
        ...diaryItems.map((x) {
          final rating = _asInt(x["rating"]).clamp(0, 5);
          final note = _asStr(x["note"]).trim();
          final title = _diaryTitle(x);
          final date = _diaryDate(x);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
                        color: _AppColors.primaryGreen.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded, color: _AppColors.primaryGreen, size: 22),
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
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _AppColors.textPrimary, height: 1.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.25)),
                      ),
                      child: Text(
                        "$rating/5",
                        style: const TextStyle(color: _AppColors.primaryGreen, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _AppColors.primaryGreen.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.08)),
                    ),
                    child: Text(
                      note,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _AppColors.textPrimary, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadDiary,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Обновить", style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primaryGreen,
              foregroundColor: _AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
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
  final c = color ?? _primary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(
          "$title: ",
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 10,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 10,
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
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _primary.withOpacity(0.18),
          _primary.withOpacity(0.06),
          _card,
        ],
      ),
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
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(_design.cardRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: _AppColors.textSecondary, height: 1.3),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
                  TextSpan(text: value),
                ],
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
  final typeController = TextEditingController();
  final titleController = TextEditingController();
  final valueController = TextEditingController();
  final commentController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  XFile? selectedFile;
  bool isUploading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Добавить запись',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(typeController, 'Тип записи (Травма, Осмотр...)'),
                const SizedBox(height: 10),
                _buildStyledTextField(titleController, 'Название'),
                const SizedBox(height: 10),
                _buildStyledTextField(valueController, 'Описание / Значение'),
                const SizedBox(height: 10),
                _buildStyledTextField(commentController, 'Комментарий'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                          style: const TextStyle(
                            color: _AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          color: _AppColors.primaryGreen,
                          size: 18,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (file != null) {
                      setModalState(() => selectedFile = file);
                    }
                  },
                  icon: const Icon(Icons.image_rounded, size: 16),
                  label: Text(
                    selectedFile != null
                        ? 'Изображение: ${selectedFile!.name}'
                        : 'Выбрать изображение',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                    foregroundColor: _AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickMedia();
                    if (file != null) {
                      setModalState(() => selectedFile = file);
                    }
                  },
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: Text(
                    selectedFile != null
                        ? 'Файл: ${selectedFile!.name}'
                        : 'Прикрепить файл (PDF, DOC, и т.д.)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                    foregroundColor: _AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                if (selectedFile != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _AppColors.primaryGreen.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: _AppColors.primaryGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Файл готов к загрузке',
                            style: TextStyle(
                              fontSize: 12,
                              color: _AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            setModalState(() => isUploading = true);
                            
                            final uri = Uri.parse('$_apiBase/medical/add_record.php');
                            final request = http.MultipartRequest('POST', uri);

                            request.fields['user_id'] = widget.player['user_id'].toString();
                            request.fields['type'] = typeController.text.trim();
                            request.fields['title'] = titleController.text.trim();
                            request.fields['value'] = valueController.text.trim();
                            request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                            request.fields['comment'] = commentController.text.trim();

                            if (selectedFile != null) {
                              request.files.add(
                                await http.MultipartFile.fromPath(
                                  'file',
                                  selectedFile!.path,
                                  filename: selectedFile!.name,
                                ),
                              );
                            }

                            try {
                              final response = await request.send();
                              final responseBody = await response.stream.bytesToString();
                              final jsonResponse = jsonDecode(responseBody);
                              
                              if (mounted) {
                                Navigator.pop(context);
                                
                                if (jsonResponse['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Запись успешно добавлена'),
                                      backgroundColor: _AppColors.success,
                                    ),
                                  );
                                  _loadMedicalRecords();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        jsonResponse['error'] ?? 'Ошибка при сохранении',
                                      ),
                                      backgroundColor: _AppColors.error,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ошибка: $e'),
                                    backgroundColor: _AppColors.error,
                                  ),
                                );
                              }
                              debugPrint('Error adding medical record: $e');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_AppColors.white),
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(
                              color: _AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  void _showEditMedicalRecordDialog(Map<String, dynamic> record) {
    final typeController = TextEditingController(text: record['type']?.toString() ?? '');
    final titleController = TextEditingController(text: record['title']?.toString() ?? '');
    final valueController = TextEditingController(text: record['value']?.toString() ?? '');
    final commentController = TextEditingController(text: record['comment']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now();
    XFile? selectedFile;

    final recordId = record['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Редактировать',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
                const SizedBox(height: 16),
                _buildStyledTextField(typeController, 'Тип записи'),
                const SizedBox(height: 10),
                _buildStyledTextField(titleController, 'Название'),
                const SizedBox(height: 10),
                _buildStyledTextField(valueController, 'Значение'),
                const SizedBox(height: 10),
                _buildStyledTextField(commentController, 'Комментарий'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                          style: const TextStyle(color: _AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_rounded, color: _AppColors.primaryGreen, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setModalState(() => selectedDate = picked);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery);
                    if (file != null) setModalState(() => selectedFile = file);
                  },
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: Text(selectedFile != null ? 'Новый файл выбран' : 'Заменить файл', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                    foregroundColor: _AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.parse('$_apiBase/medical/update_record.php');
                      final request = http.MultipartRequest('POST', uri);

                      request.fields['id'] = recordId.toString();
                      request.fields['type'] = typeController.text.trim();
                      request.fields['title'] = titleController.text.trim();
                      request.fields['value'] = valueController.text.trim();
                      request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                      request.fields['comment'] = commentController.text.trim();

                      if (selectedFile != null) {
                        request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path));
                      }

                      try {
                        final response = await request.send();
                        if (response.statusCode == 200) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          _loadMedicalRecords();
                        }
                      } catch (e) {
                        debugPrint('Error updating medical record: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Сохранить',
                        style: TextStyle(color: _AppColors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  void _assignTraining() {
    final playerId = widget.player['user_id'];
    if (playerId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AddTrainingScreen(playerId: playerId)));
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _textPrimary,
        onPressed: () => Get.back(),
      ),
      title: Text(
        "Профиль игрока",
        style: _titleStyle(size: 18, color: _textPrimary),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.palette_outlined, color: _primary, size: 20),
          onPressed: _openDesignEditor,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: _designLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.refresh_rounded, color: _primary, size: 20),
          onPressed: () async {
            _loadMedicalRecords();
            _parseSportData();
            _parseMedia();
            await _loadDesignFromServer();

            if (_selectedTabIndex == 6) {
              await _loadDiary();
            }

            if (_selectedTabIndex == 4) {
              if (_trainingSubTab == 0) {
                await _loadPlayerTrainingHistory(force: true);
              }
              if (_trainingSubTab == 1) {
                await _loadAttendanceLog(force: true);
              }
              await _loadTeamCalendar(force: true);
            }

            if (_selectedTabIndex == 5) {
              await _loadMatches(force: true);
            }
          },
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _buildContent()),
        ],
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