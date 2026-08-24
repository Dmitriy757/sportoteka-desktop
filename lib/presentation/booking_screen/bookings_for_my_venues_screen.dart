import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class BookingsForMyVenuesScreen extends StatefulWidget {
  const BookingsForMyVenuesScreen({super.key});

  @override
  State<BookingsForMyVenuesScreen> createState() =>
      _BookingsForMyVenuesScreenState();
}

class _BookingsForMyVenuesScreenState
    extends State<BookingsForMyVenuesScreen> {
  List<Map<String, dynamic>> bookings = <Map<String, dynamic>>[];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _BookingUi.text,
    double height = 1.25,
  }) =>
      AppTypography.custom(
        size: size,
        weight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );

  Widget _dot(
    Color color, {
    double size = 5,
  }) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
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

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    final ownerId = await PrefUtils.getUserId();

    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/'
      'get_venue_bookings_by_owner.php?owner_id=$ownerId',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map && data['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            bookings = List<Map<String, dynamic>>.from(
              (data['bookings'] as List?) ?? const <dynamic>[],
            );
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

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
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _BookingUi.green,
                        ),
                      )
                    : bookings.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            color: _BookingUi.green,
                            onRefresh: _loadBookings,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: bookings.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, index) =>
                                  _bookingCard(bookings[index]),
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
                  'Бронирования площадок',
                  style: _t(
                    14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Заявки на ваши спортивные объекты',
                  style: _t(
                    9.6,
                    color: _BookingUi.muted,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: _BookingUi.soft,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: _loadBookings,
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: _BookingUi.greenDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final title = '${booking['title'] ?? ''}'.trim();
    final date = '${booking['date'] ?? ''}'.trim();
    final time = '${booking['time_slot'] ?? ''}'.trim();
    final first = '${booking['first_name'] ?? ''}'.trim();
    final last = '${booking['last_name'] ?? ''}'.trim();
    final email = '${booking['email'] ?? ''}'.trim();

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
                size: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.isEmpty ? 'Площадка' : title,
                  style: _t(
                    11.8,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _pill(
                'Дата',
                date,
                _BookingUi.greenDark,
              ),
              _pill(
                'Время',
                time,
                _BookingUi.amber,
              ),
            ],
          ),
          if ('$first $last'.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            _line(
              'Кто бронировал',
              '$first $last'.trim(),
              _BookingUi.green,
            ),
          ],
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _line(
              'Email',
              email,
              _BookingUi.muted2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _dot(
            color,
            size: 4.5,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${value.isEmpty ? '—' : value}',
            style: _t(
              9.3,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _dot(
            color,
            size: 4.5,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$label: $value',
            style: _t(
              9.6,
              color: _BookingUi.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BookingUi.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _brandDots(color: _BookingUi.amber),
            const SizedBox(width: 9),
            Text(
              'Нет бронирований ваших площадок',
              style: _t(
                10.2,
                color: _BookingUi.muted,
              ),
            ),
          ],
        ),
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
