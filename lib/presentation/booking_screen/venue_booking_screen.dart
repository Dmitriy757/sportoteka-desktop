import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';

class VenueBookingScreen extends StatefulWidget {
  final int venueId;
  final String venueTitle;
  final int userId;

  const VenueBookingScreen({
    super.key,
    required this.venueId,
    required this.venueTitle,
    required this.userId,
  });

  @override
  State<VenueBookingScreen> createState() =>
      _VenueBookingScreenState();
}

class _VenueBookingScreenState extends State<VenueBookingScreen> {
  String? address;
  String? conditions;
  String? description;
  String? imageUrl;

  DateTime selectedDate = DateTime.now();

  final int startHour = 9;
  final int endHour = 22;
  int slotStepMinutes = 60;

  Set<String> bookedSlots = <String>{};
  String? _selectedTimeSlot;

  bool isLoading = true;
  bool isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadVenueDetails();
    _fetchBookedSlots();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _BookingUi.text,
    double height = 1.25,
  }) {
    final TextStyle base;

    if (size >= 14.0) {
      base = AppTypography.screenTitle(color: color);
    } else if (size >= 12.3) {
      base = AppTypography.subsectionTitle(color: color);
    } else if (size >= 11.3) {
      base = AppTypography.itemTitle(color: color);
    } else if (size >= 10.1) {
      base = AppTypography.body(color: color);
    } else if (size >= 9.5) {
      base = AppTypography.secondary(color: color);
    } else if (size >= 9.0) {
      base = AppTypography.caption(color: color);
    } else {
      base = AppTypography.menuGroup(color: color);
    }

    return base.copyWith(
      fontWeight: weight,
      color: color,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
    bool glow = false,
  }) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 2,
                  ),
                ]
              : null,
        ),
      );

  Widget _brandDots({
    Color color = _BookingUi.green,
  }) {
    const values = <List<double>>[
      <double>[3.5, .34],
      <double>[4.5, .48],
      <double>[5.5, .68],
      <double>[6.5, 1],
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1)
            const SizedBox(width: 3),
        ],
      ],
    );
  }

  Future<void> _loadVenueDetails() async {
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/'
        'get_venue_details.php?venue_id=${widget.venueId}',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return;

      final data = json.decode(res.body);

      if (data is! Map || data['status'] != 'success') return;

      final dynamic venueRaw = data['venue'];
      final Map<String, dynamic> venue = venueRaw is Map
          ? Map<String, dynamic>.from(venueRaw)
          : <String, dynamic>{};

      String? rawUrl = venue['image_url']?.toString();

      if (rawUrl != null &&
          rawUrl.trim().toLowerCase() == 'null') {
        rawUrl = null;
      }

      rawUrl = rawUrl?.trim();

      if (rawUrl != null &&
          rawUrl.isNotEmpty &&
          !rawUrl.startsWith('http')) {
        if (!rawUrl.startsWith('/')) {
          rawUrl = '/$rawUrl';
        }
        rawUrl = 'https://sportotekaapp.ru$rawUrl';
      }

      final normalizedUrl =
          rawUrl != null && rawUrl.isNotEmpty
              ? Uri.encodeFull(rawUrl)
              : null;

      if (!mounted) return;

      setState(() {
        address = venue['address']?.toString();
        conditions = venue['conditions']?.toString();
        description = venue['description']?.toString();
        imageUrl = normalizedUrl;
      });
    } catch (_) {}
  }

  Future<void> _fetchBookedSlots() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _selectedTimeSlot = null;
      });
    }

    try {
      final dateStr = _formatYMD(selectedDate);

      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/'
        'get_booked_slots.php?venue_id=${widget.venueId}&date=$dateStr',
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data is Map && data['status'] == 'success') {
          bookedSlots = Set<String>.from(
            (data['booked_slots'] as List?) ?? const <dynamic>[],
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _bookSlot(String timeSlot) async {
    if (isBooking) return;

    setState(() => isBooking = true);

    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/book_slot.php',
      );

      final res = await http.post(
        uri,
        body: <String, String>{
          'venue_id': widget.venueId.toString(),
          'user_id': widget.userId.toString(),
          'date': _formatYMD(selectedDate),
          'time_slot': timeSlot,
        },
      );

      final data = json.decode(res.body);

      if (data is Map && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование успешно'),
            ),
          );
        }

        await _fetchBookedSlots();
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка: ${data is Map ? data['message'] ?? 'Не удалось забронировать' : 'Не удалось забронировать'}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сеть недоступна, повторите попытку',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isBooking = false);
      }
    }
  }

  String _formatYMD(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<String> _generateTimeSlots() {
    final slots = <String>[];

    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    for (int hour = startHour; hour < endHour; hour++) {
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        hour,
      );

      final end = start.add(
        Duration(minutes: slotStepMinutes),
      );

      if (end.hour > endHour ||
          (end.hour == endHour && end.minute > 0)) {
        break;
      }

      final startStr =
          '${start.hour.toString().padLeft(2, '0')}:'
          '${start.minute.toString().padLeft(2, '0')}';

      final endStr =
          '${end.hour.toString().padLeft(2, '0')}:'
          '${end.minute.toString().padLeft(2, '0')}';

      slots.add('$startStr-$endStr');
    }

    return slots;
  }

  bool _isPastTodaySlot(String slot) {
    final now = DateTime.now();

    final isToday =
        now.year == selectedDate.year &&
        now.month == selectedDate.month &&
        now.day == selectedDate.day;

    if (!isToday) return false;

    final startPart = slot.split('-').first;
    final parts = startPart.split(':');

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final slotStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
      minute,
    );

    return slotStart.isBefore(now);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 90),
      ),
    );

    if (picked == null) return;

    setState(() => selectedDate = picked);
    await _fetchBookedSlots();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final timeSlots = _generateTimeSlots();

    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: _BookingUi.text,
          displayColor: _BookingUi.text,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _header(),
              const Divider(
                height: 1,
                thickness: .6,
                color: _BookingUi.line,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _BookingUi.green,
                  onRefresh: _fetchBookedSlots,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      22,
                    ),
                    children: <Widget>[
                      if (imageUrl != null &&
                          imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 16 / 8.5,
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(),
                            ),
                          ),
                        )
                      else
                        AspectRatio(
                          aspectRatio: 16 / 8.5,
                          child: _imagePlaceholder(),
                        ),
                      const SizedBox(height: 8),
                      _venueInfo(),
                      const SizedBox(height: 8),
                      _dateAndDuration(),
                      const SizedBox(height: 8),
                      _legend(),
                      const SizedBox(height: 8),
                      if (isLoading)
                        _loadingGridSkeleton()
                      else
                        _slotGrid(timeSlots),
                      const SizedBox(height: 12),
                      _bookButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Material(
            color: _BookingUi.soft,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: _BookingUi.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _brandDots(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.venueTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    14.3,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Выберите дату и свободное время',
                  style: _t(
                    9.5,
                    color: _BookingUi.muted,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: _BookingUi.greenSoft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                child: Row(
                  children: <Widget>[
                    _dot(
                      _BookingUi.green,
                      size: 4.5,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatYMD(selectedDate),
                      style: _t(
                        9.2,
                        weight: FontWeight.w600,
                        color: _BookingUi.greenDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueInfo() {
    final rows = <Widget>[];

    if ((address ?? '').trim().isNotEmpty) {
      rows.add(
        _infoRow(
          'Адрес',
          address!.trim(),
          _BookingUi.greenDark,
        ),
      );
    }

    if ((conditions ?? '').trim().isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 7));
      rows.add(
        _infoRow(
          'Условия',
          conditions!.trim(),
          _BookingUi.amber,
        ),
      );
    }

    if ((description ?? '').trim().isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 7));
      rows.add(
        _infoRow(
          'Описание',
          description!.trim(),
          _BookingUi.green,
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: _dot(
            color,
            size: 4.5,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.body(
                color: _BookingUi.muted,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '$title: ',
                  style: AppTypography.bodyMedium(
                    color: _BookingUi.text,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateAndDuration() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _dot(
                _BookingUi.green,
                size: 5,
              ),
              const SizedBox(width: 7),
              Text(
                'Длительность слота',
                style: _t(
                  10.5,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <int>[30, 60, 90].map((minutes) {
              final selected = slotStepMinutes == minutes;

              return Material(
                color: selected
                    ? _BookingUi.greenSoft
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () async {
                    setState(() {
                      slotStepMinutes = minutes;
                      _selectedTimeSlot = null;
                    });
                    await _fetchBookedSlots();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _dot(
                          selected
                              ? _BookingUi.green
                              : _BookingUi.muted2,
                          size: selected ? 5 : 4,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$minutes мин',
                          style: _t(
                            9.4,
                            weight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? _BookingUi.greenDark
                                : _BookingUi.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: <Widget>[
        _legendItem(
          'Свободно',
          _BookingUi.green,
        ),
        _legendItem(
          'Выбрано',
          _BookingUi.amber,
        ),
        _legendItem(
          'Занято / прошло',
          _BookingUi.muted2,
        ),
      ],
    );
  }

  Widget _legendItem(
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _dot(
          color,
          size: 4.5,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: _t(
            9.1,
            color: _BookingUi.muted,
          ),
        ),
      ],
    );
  }

  Widget _slotGrid(List<String> slots) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 760
            ? 5
            : constraints.maxWidth >= 520
                ? 4
                : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 2.35,
          ),
          itemBuilder: (_, index) {
            final slot = slots[index];
            final booked = bookedSlots.contains(slot);
            final past = _isPastTodaySlot(slot);
            final disabled = booked || past;
            final selected = _selectedTimeSlot == slot;

            final color = disabled
                ? const Color(0xFFE7EAE8)
                : selected
                    ? _BookingUi.amberSoft
                    : _BookingUi.greenSoft;

            final dotColor = disabled
                ? _BookingUi.muted2
                : selected
                    ? _BookingUi.amber
                    : _BookingUi.green;

            return Material(
              color: color,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: disabled
                    ? null
                    : () => setState(
                          () => _selectedTimeSlot = slot,
                        ),
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _dot(
                        dotColor,
                        size: 4.5,
                        glow: selected,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        slot,
                        style: _t(
                          9.2,
                          weight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: disabled
                              ? _BookingUi.muted2
                              : _BookingUi.text,
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

  Widget _loadingGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE7EAE8),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _bookButton() {
    final canBook =
        _selectedTimeSlot != null && !isBooking;

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: canBook
            ? () => _bookSlot(_selectedTimeSlot!)
            : null,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: _BookingUi.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: isBooking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _selectedTimeSlot == null
                    ? 'Выберите время'
                    : 'Забронировать ${_selectedTimeSlot!}',
                style: _t(
                  10.2,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F4F1),
      alignment: Alignment.center,
      child: _brandDots(
        color: _BookingUi.greenDark,
      ),
    );
  }
}


class _BookingUi {
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color line = Color(0xFFEEF1EF);
}
