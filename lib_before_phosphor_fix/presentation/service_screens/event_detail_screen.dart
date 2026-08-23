import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

class EventDetailPalette {
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
  static const danger = Color(0xFFE53935);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> filteredParticipants = [];

  bool isLoadingParticipants = true;
  bool isRegistering = false;
  String searchQuery = '';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  String _attendanceType = 'Сам(а)';

  final List<String> _attendanceTypes = const [
    'Сам(а)',
    'С ребёнком',
    'С командой',
    'С семьёй',
    'Как представитель клуба',
  ];

  int get _eventId => int.tryParse('${widget.event['id'] ?? 0}') ?? 0;

  int get _participantsCount =>
      int.tryParse('${widget.event['participants'] ?? 0}') ?? participants.length;

  int get _maxParticipants {
    final raw = int.tryParse('${widget.event['max_participants'] ?? 10000}') ?? 10000;
    return raw < 10000 ? 10000 : raw;
  }

  String get _eventTitle => (widget.event['title'] ?? 'Мероприятие').toString();

  String get _eventDate => (widget.event['event_date'] ?? '').toString();

  String get _eventLocation {
    final value = (widget.event['location'] ?? '').toString().trim();
    return value.isEmpty ? 'Локация не указана' : value;
  }

  String get _eventDescription {
    final value = (widget.event['description'] ?? '').toString().trim();
    return value.isEmpty ? 'Описание отсутствует' : value;
  }

  String get _eventImage => (widget.event['image'] ?? '').toString();

  String get _eventSport {
    final value = (widget.event['sport'] ?? '').toString().trim();
    return value.isEmpty ? 'Спорт' : value;
  }

  bool get _isFull => _participantsCount >= _maxParticipants;

  @override
  void initState() {
    super.initState();
    _loadParticipants(_eventId);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants(int eventId) async {
    if (eventId == 0) {
      setState(() {
        participants = [];
        filteredParticipants = [];
        isLoadingParticipants = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://sportotekaapp.ru/api/get_event_participants.php?event_id=$eventId',
        ),
      );

      final data = json.decode(response.body);

      setState(() {
        participants = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        isLoadingParticipants = false;
      });
    } catch (e) {
      setState(() {
        participants = [];
        filteredParticipants = [];
        isLoadingParticipants = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = participants;

    if (searchQuery.isNotEmpty) {
      temp = temp.where((p) {
        final fullName =
            '${p['first_name'] ?? ''} ${p['last_name'] ?? ''} ${p['full_name'] ?? ''}'
                .toLowerCase();
        return fullName.contains(searchQuery.toLowerCase());
      }).toList();
    }

    filteredParticipants = temp;
    if (mounted) setState(() {});
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EventDetailPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EventDetailPalette.border),
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

  Widget _metricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: EventDetailPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EventDetailPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: EventDetailPalette.primaryGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: EventDetailPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
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
              color: EventDetailPalette.text,
            ),
          ),
        ),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: EventDetailPalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: EventDetailPalette.textMuted,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: EventDetailPalette.primaryGreen),
      filled: true,
      fillColor: EventDetailPalette.background,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EventDetailPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: EventDetailPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: EventDetailPalette.primaryGreen,
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _registerForEvent(int eventId) async {
    if (isRegistering) return;

    final userId = await PrefUtils.getUserId();

    if (userId == null || userId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: не удалось получить ID пользователя'),
        ),
      );
      return;
    }

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final comment = _commentController.text.trim();
    final attendanceType = _attendanceType;

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ФИО')),
      );
      return;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите телефон')),
      );
      return;
    }

    setState(() => isRegistering = true);

    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/register_event.php'),
        body: {
          'event_id': eventId.toString(),
          'user_id': userId.toString(),
          'full_name': fullName,
          'phone': phone,
          'attendance_type': attendanceType,
          'comment': comment,
        },
      );

      final data = json.decode(res.body);

      if (!mounted) return;

      if (data['success'] == true) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка на участие отправлена')),
        );

        _fullNameController.clear();
        _phoneController.clear();
        _commentController.clear();
        _attendanceType = 'Сам(а)';

        await _loadParticipants(eventId);

        setState(() {
          widget.event['participants'] = participants.length;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Ошибка регистрации'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isRegistering = false);
      }
    }
  }

  Future<void> _showRegistrationSheet() async {
    if (_isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Лимит участников уже достигнут')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: EventDetailPalette.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: EventDetailPalette.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Заявка на участие',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: EventDetailPalette.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _eventTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: EventDetailPalette.text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _metricChip(Icons.calendar_today_rounded, _eventDate),
                                  _metricChip(Icons.location_on_outlined, _eventLocation),
                                  _metricChip(Icons.sports_rounded, _eventSport),
                                  _metricChip(
                                    Icons.group_outlined,
                                    '$_participantsCount / $_maxParticipants',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _fullNameController,
                          decoration: _inputDecoration(
                            hint: 'ФИО',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            hint: 'Телефон',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: EventDetailPalette.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: EventDetailPalette.border),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _attendanceType,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.how_to_reg_rounded,
                                color: EventDetailPalette.primaryGreen,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            items: _attendanceTypes.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                _attendanceType = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            hint: 'Комментарий или дополнительная информация',
                            icon: Icons.edit_note_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: EventDetailPalette.text,
                                  side: const BorderSide(
                                    color: EventDetailPalette.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Отмена',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: EventDetailPalette.greenGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: isRegistering
                                      ? null
                                      : () => _registerForEvent(_eventId),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isRegistering
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Отправить заявку',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
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
          },
        );
      },
    );
  }

  Widget _buildParticipantsSection() {
    if (filteredParticipants.isEmpty) {
      return _whiteCard(
        child: const Text(
          'Пока нет участников по вашему поиску',
          style: TextStyle(
            color: EventDetailPalette.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredParticipants.map((user) {
        final fullName = (user['full_name'] != null &&
                user['full_name'].toString().trim().isNotEmpty)
            ? user['full_name'].toString().trim()
            : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();

        final phone = (user['phone'] ?? '').toString().trim();
        final attendanceType = (user['attendance_type'] ?? '').toString().trim();
        final photoUrl =
            user['photo'] != null && user['photo'].toString().isNotEmpty
                ? 'https://sportoteka.by/${user['photo']}'
                : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _whiteCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  backgroundColor: EventDetailPalette.lightGreen,
                  child: photoUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: EventDetailPalette.primaryGreen,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Участник' : fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: EventDetailPalette.text,
                        ),
                      ),
                      if (attendanceType.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          attendanceType,
                          style: const TextStyle(
                            color: EventDetailPalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: EventDetailPalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: EventDetailPalette.primaryGreen,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Открытие чата с $fullName...')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EventDetailPalette.primaryGreen.withOpacity(0.12),
            EventDetailPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EventDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: EventDetailPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.event_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _eventTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: EventDetailPalette.text,
                    height: 1.2,
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
              _metricChip(Icons.calendar_today_rounded, _eventDate),
              _metricChip(Icons.location_on_outlined, _eventLocation),
              _metricChip(Icons.sports_rounded, _eventSport),
              _metricChip(
                Icons.group_outlined,
                '$_participantsCount / $_maxParticipants',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard() {
    final progress = _maxParticipants == 0
        ? 0.0
        : (_participantsCount / _maxParticipants).clamp(0.0, 1.0);

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Запись на мероприятие'),
          const SizedBox(height: 10),
          Text(
            _isFull
                ? 'Лимит участников достигнут'
                : 'Заполните короткую форму и отправьте заявку на участие',
            style: TextStyle(
              color: _isFull
                  ? EventDetailPalette.danger
                  : EventDetailPalette.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: EventDetailPalette.lightGreen,
              color: _isFull
                  ? EventDetailPalette.danger
                  : EventDetailPalette.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Сейчас записано $_participantsCount человек из $_maxParticipants',
            style: const TextStyle(
              color: EventDetailPalette.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: _isFull ? null : EventDetailPalette.greenGradient,
                color: _isFull ? Colors.grey.shade400 : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: (_isFull || isRegistering) ? null : _showRegistrationSheet,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  _isFull ? 'Регистрация закрыта' : 'Записаться на мероприятие',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventDetailPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: EventDetailPalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Мероприятие',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: EventDetailPalette.text,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildHeaderCard(),
          if (_eventImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  _eventImage,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _whiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Описание'),
                  const SizedBox(height: 10),
                  Text(
                    _eventDescription,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: EventDetailPalette.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildRegistrationCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _sectionTitle(
              'Участники мероприятия',
              action: '${participants.length}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _whiteCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                onChanged: (value) {
                  searchQuery = value;
                  _applyFilters();
                },
                decoration: const InputDecoration(
                  hintText: 'Поиск по имени...',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: isLoadingParticipants
                ? _whiteCard(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: EventDetailPalette.primaryGreen,
                        ),
                      ),
                    ),
                  )
                : _buildParticipantsSection(),
          ),
        ],
      ),
    );
  }
}