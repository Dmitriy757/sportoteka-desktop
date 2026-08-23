import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';

class SchedulePalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const gold = Color(0xFFFFC83D);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ScheduleScreen extends StatefulWidget {
  final String sport;
  const ScheduleScreen({super.key, required this.sport});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const int kUpcomingChunkDays = 30;
  static const int kUpcomingTarget = 50;
  static const int kParallel = 6;
  static const Duration kUpcomingCacheTtl = Duration(minutes: 10);

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _bannerImage;

  final Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  final Map<int, List<String>> _participants = {};
  List<Map<String, dynamic>> _upcoming = [];

  bool _showCalendar = true;
  bool _showHint = true;
  bool _isLoadingDay = false;
  bool _isLoadingUpcoming = false;
  bool _isLoadingMore = false;
  String? _errorDay;
  String? _errorUpcoming;

  Map<String, dynamic>? _upcomingCache;
  int _upcomingOffsetDays = 0;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtNiceDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) =>
      _eventsByDay[_dayKey(day)] ?? const [];

  @override
  void initState() {
    super.initState();
    _loadEventsForDay(_selectedDay);
    _loadUpcomingEvents(reset: true);
  }

  @override
  void dispose() {
    _eventController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsForDay(DateTime day) async {
    setState(() {
      _isLoadingDay = true;
      _errorDay = null;
    });

    try {
      final key = _dayKey(day);
      final dateStr = _fmtDate(key);
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_events.php?date=$dateStr&sport=${Uri.encodeComponent(widget.sport)}',
      );
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        final list = List<Map<String, dynamic>>.from(data);
        setState(() => _eventsByDay[key] = list);

        for (final e in list) {
          final id = e['id'];
          if (id != null) {
            _loadParticipants(id as int);
          }
        }
      } else {
        setState(() => _errorDay = 'Ошибка загрузки (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _errorDay = 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDay = false);
      }
    }
  }

  Future<void> _loadUpcomingEvents({required bool reset}) async {
    setState(() {
      if (reset) {
        _isLoadingUpcoming = true;
        _upcoming = [];
        _upcomingOffsetDays = 0;
        _errorUpcoming = null;
      } else {
        _isLoadingMore = true;
        _errorUpcoming = null;
      }
    });

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (reset && _upcomingCache != null) {
      final cacheAge = nowMs - (_upcomingCache!['time'] as int);
      if (cacheAge < kUpcomingCacheTtl.inMilliseconds) {
        setState(() {
          _upcoming =
              List<Map<String, dynamic>>.from(_upcomingCache!['items'] as List);
          _isLoadingUpcoming = false;
        });
        return;
      }
    }

    final today = _dayKey(DateTime.now());
    final start = today.add(Duration(days: _upcomingOffsetDays));
    final endExclusive = start.add(const Duration(days: kUpcomingChunkDays));

    try {
      final collected = <Map<String, dynamic>>[];

      DateTime cursor = start;
      while (cursor.isBefore(endExclusive)) {
        final futures = <Future<List<Map<String, dynamic>>>>[];
        for (int i = 0; i < kParallel && cursor.isBefore(endExclusive); i++) {
          final d = cursor;
          futures.add(_fetchDay(d));
          cursor = cursor.add(const Duration(days: 1));
        }

        final results = await Future.wait(futures);
        for (final list in results) {
          collected.addAll(list);
        }

        if (reset && (_upcoming.length + collected.length) >= kUpcomingTarget) {
          break;
        }
      }

      for (final e in collected) {
        e['event_date'] ??= _fmtDate(start);
      }

      collected.sort((a, b) {
        final ad = DateTime.tryParse((a['event_date'] ?? '') as String) ?? today;
        final bd = DateTime.tryParse((b['event_date'] ?? '') as String) ?? today;
        final c = ad.compareTo(bd);
        if (c != 0) return c;
        return (a['id'] ?? 0).toString().compareTo((b['id'] ?? 0).toString());
      });

      setState(() {
        _upcoming.addAll(collected);
        _upcomingOffsetDays += kUpcomingChunkDays;
        if (reset) {
          _upcomingCache = {
            "time": nowMs,
            "items": _upcoming,
          };
        }
      });

      for (final e in collected.take(30)) {
        final id = e['id'];
        if (id != null) {
          _loadParticipants(id as int);
        }
      }
    } catch (e) {
      setState(() => _errorUpcoming = 'Ошибка загрузки ближайших событий: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUpcoming = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDay(DateTime d) async {
    final dateStr = _fmtDate(d);
    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/get_events.php?date=$dateStr&sport=${Uri.encodeComponent(widget.sport)}',
    );
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = json.decode(res.body) as List;
      final list = List<Map<String, dynamic>>.from(data);
      for (final e in list) {
        e['event_date'] ??= dateStr;
      }
      return list;
    }

    return const [];
  }

  Future<void> _loadParticipants(int eventId) async {
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_event_participants.php?event_id=$eventId',
      );
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        setState(() {
          _participants[eventId] = data
              .map((p) => '${p['first_name']} ${p['last_name']} • ${p['role']}')
              .cast<String>()
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickBannerImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bannerImage = File(picked.path));
    }
  }

  Future<void> _addEvent() async {
    final title = _eventController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название мероприятия')),
      );
      return;
    }

    final dateStr = _fmtDate(_dayKey(_selectedDay));
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://sportotekaapp.ru/api/add_event.php'),
    )
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['sport'] = widget.sport
      ..fields['event_date'] = dateStr
      ..fields['max_participants'] = '20';

    if (_bannerImage != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'banner',
          _bannerImage!.path,
          contentType: MediaType('image', 'jpeg'),
          filename: path.basename(_bannerImage!.path),
        ),
      );
    }

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      final data = json.decode(res.body);

      if (data['success'] == true) {
        _eventController.clear();
        _descriptionController.clear();
        setState(() => _bannerImage = null);

        await _loadEventsForDay(_selectedDay);
        await _loadUpcomingEvents(reset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Мероприятие создано')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Ошибка добавления события'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _registerForEvent(int eventId) async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: не удалось получить ID пользователя'),
        ),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/register_event.php'),
        body: {
          'event_id': '$eventId',
          'user_id': '$userId',
        },
      );
      final data = json.decode(res.body);

      if (data['success'] == true) {
        await _loadEventsForDay(_selectedDay);
        await _loadUpcomingEvents(reset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы записаны')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Ошибка регистрации')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 2, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: first,
      lastDate: last,
      helpText: 'Выберите дату мероприятия',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: SchedulePalette.primaryGreen,
                  surface: Colors.white,
                  onSurface: SchedulePalette.text,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDay = DateTime(picked.year, picked.month, picked.day);
        _focusedDay = _selectedDay;
      });
      await _loadEventsForDay(_selectedDay);
    }
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SchedulePalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SchedulePalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }

  Widget _sectionTitle(String title, {String? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: SchedulePalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: SchedulePalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SchedulePalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SchedulePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SchedulePalette.primaryGreen),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: SchedulePalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SchedulePalette.primaryGreen.withOpacity(0.12),
            SchedulePalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SchedulePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: SchedulePalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Расписание • ${widget.sport}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: SchedulePalette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Календарь, события и ближайшие мероприятия',
                      style: TextStyle(
                        color: SchedulePalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = DateTime.now();
                    _focusedDay = DateTime.now();
                  });
                  _loadEventsForDay(_selectedDay);
                },
                child: const Text(
                  'Сегодня',
                  style: TextStyle(
                    color: SchedulePalette.primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                Icons.event_available_rounded,
                'Выбрано ${_fmtNiceDate(_selectedDay)}',
              ),
              _metricChip(
                Icons.view_agenda_rounded,
                'Сегодня ${_getEventsForDay(_selectedDay).length}',
              ),
              _metricChip(
                Icons.upcoming_rounded,
                'Ближайших ${_upcoming.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: SchedulePalette.greenGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Создать мероприятие'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _whiteCard(
            padding: EdgeInsets.zero,
            child: IconButton(
              tooltip: _showCalendar ? 'Скрыть календарь' : 'Показать календарь',
              onPressed: () => setState(() => _showCalendar = !_showCalendar),
              icon: Icon(
                _showCalendar
                    ? Icons.calendar_view_month_rounded
                    : Icons.calendar_today_rounded,
                color: SchedulePalette.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: SchedulePalette.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: SchedulePalette.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Создать мероприятие',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SchedulePalette.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: SchedulePalette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SchedulePalette.border),
                    ),
                    child: TextField(
                      controller: _eventController,
                      decoration: const InputDecoration(
                        hintText: 'Название',
                        prefixIcon: Icon(
                          Icons.title_rounded,
                          color: SchedulePalette.primaryGreen,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: SchedulePalette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SchedulePalette.border),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Описание',
                        prefixIcon: Icon(
                          Icons.description_rounded,
                          color: SchedulePalette.primaryGreen,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _whiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: SchedulePalette.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Дата: ${_fmtDate(_selectedDay)}',
                            style: const TextStyle(
                              color: SchedulePalette.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickEventDate,
                          child: const Text(
                            'Изменить',
                            style: TextStyle(
                              color: SchedulePalette.primaryGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickBannerImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Загрузить баннер'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: SchedulePalette.border),
                      foregroundColor: SchedulePalette.text,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_bannerImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _bannerImage!,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: SchedulePalette.greenGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _addEvent();
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Создать'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParticipantChip(String text) {
    final name = text.split('•').first.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: SchedulePalette.superLightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SchedulePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: SchedulePalette.primaryGreen,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: SchedulePalette.text,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e, {bool showDateBadge = true}) {
    final id = e['id'] as int?;
    final title = (e['title'] ?? '') as String;
    final desc = (e['description'] ?? '') as String;
    final imageUrl = (e['image'] ?? '') as String;
    final participants = (e['participants'] ?? 0).toString();
    final max = (e['max_participants'] ?? 20).toString();
    final chips = id != null ? (_participants[id] ?? const []) : const <String>[];

    final dateStr = (e['event_date'] ?? '') as String;
    final date = DateTime.tryParse(dateStr);
    final niceDate = date != null
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _whiteCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: e),
            ),
          );
        },
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    child: Image.network(
                      imageUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  if (showDateBadge && niceDate.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.56),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              niceDate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: SchedulePalette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SchedulePalette.superLightGreen,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: SchedulePalette.border),
                        ),
                        child: Text(
                          widget.sport,
                          style: const TextStyle(
                            color: SchedulePalette.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SchedulePalette.text,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metricChip(
                        Icons.group_outlined,
                        'Участников: $participants из $max',
                      ),
                      if (niceDate.isNotEmpty && !showDateBadge)
                        _metricChip(Icons.event_rounded, niceDate),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      children: chips.take(6).map(_buildParticipantChip).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: e),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded),
                          label: const Text('Подробнее'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SchedulePalette.border),
                            foregroundColor: SchedulePalette.text,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: SchedulePalette.greenGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: id != null ? () => _registerForEvent(id) : null,
                            icon: const Icon(Icons.event_available_rounded),
                            label: const Text('Записаться'),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
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
    );
  }

  Widget _calendarSection() {
    return AnimatedCrossFade(
      crossFadeState:
          _showCalendar ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 250),
      firstChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showHint)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SchedulePalette.superLightGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SchedulePalette.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: SchedulePalette.primaryGreen,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Сначала выберите дату',
                          style: TextStyle(
                            color: SchedulePalette.primaryGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TableCalendar<Map<String, dynamic>>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                    _showCalendar = false;
                    _showHint = false;
                  });
                  _loadEventsForDay(selected);
                },
                eventLoader: (day) => _getEventsForDay(day),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: SchedulePalette.primaryGreen.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    gradient: SchedulePalette.greenGradient,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: SchedulePalette.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  outsideTextStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  defaultTextStyle: const TextStyle(
                    color: SchedulePalette.text,
                    fontWeight: FontWeight.w700,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: SchedulePalette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: SchedulePalette.text,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: SchedulePalette.primaryGreen,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: SchedulePalette.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _dayListOrEmpty() {
    final items = _getEventsForDay(_selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'События на выбранную дату',
            action: _fmtNiceDate(_selectedDay),
          ),
          const SizedBox(height: 8),
          if (_isLoadingDay && items.isEmpty)
            _whiteCard(
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: SchedulePalette.primaryGreen,
                  ),
                ),
              ),
            )
          else if (_errorDay != null && items.isEmpty)
            _whiteCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 34,
                    color: SchedulePalette.textMuted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorDay!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SchedulePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _loadEventsForDay(_selectedDay),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SchedulePalette.text,
                      side: const BorderSide(color: SchedulePalette.border),
                    ),
                  ),
                ],
              ),
            )
          else if (items.isEmpty)
            _whiteCard(
              child: const Column(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 34,
                    color: SchedulePalette.textMuted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'На выбранную дату нет событий',
                    style: TextStyle(
                      color: SchedulePalette.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((e) => _eventCard(e, showDateBadge: false)),
        ],
      ),
    );
  }

  Widget _upcomingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ближайшие события', action: '${_upcoming.length}'),
          const SizedBox(height: 8),
          if (_isLoadingUpcoming && _upcoming.isEmpty)
            _whiteCard(
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: SchedulePalette.primaryGreen,
                  ),
                ),
              ),
            )
          else if (_errorUpcoming != null && _upcoming.isEmpty)
            _whiteCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 34,
                    color: SchedulePalette.textMuted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorUpcoming!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SchedulePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _loadUpcomingEvents(reset: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обновить ленту'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SchedulePalette.text,
                      side: const BorderSide(color: SchedulePalette.border),
                    ),
                  ),
                ],
              ),
            )
          else if (_upcoming.isNotEmpty) ...[
            ..._upcoming.map((e) => _eventCard(e, showDateBadge: true)),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isLoadingMore ? null : () => _loadUpcomingEvents(reset: false),
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Показать ещё'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: SchedulePalette.text,
                  side: const BorderSide(color: SchedulePalette.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SchedulePalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SchedulePalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Расписание',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: SchedulePalette.text,
            fontSize: 16,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadEventsForDay(_selectedDay);
          await _loadUpcomingEvents(reset: true);
        },
        color: SchedulePalette.primaryGreen,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeaderCard(),
            _buildActionButtons(),
            _calendarSection(),
            _dayListOrEmpty(),
            _upcomingSection(),
          ],
        ),
      ),
    );
  }
}