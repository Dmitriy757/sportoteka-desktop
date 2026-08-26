import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Map<String, dynamic>> bookings = <Map<String, dynamic>>[];
  bool isLoading = true;
  int? userId;

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

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    userId = await PrefUtils.getUserId();

    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/get_user_bookings.php?user_id=$userId',
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

  Future<void> _cancelBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: <Widget>[
              _dot(
                _BookingUi.red,
                size: 6,
              ),
              const SizedBox(width: 8),
              Text(
                'Отменить бронирование?',
                style: _t(
                  12.5,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'Бронь будет отменена и время снова станет доступным.',
            style: _t(
              10,
              color: _BookingUi.muted,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Оставить',
                style: _t(
                  9.8,
                  weight: FontWeight.w600,
                  color: _BookingUi.muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Отменить бронь',
                style: _t(
                  9.8,
                  weight: FontWeight.w600,
                  color: _BookingUi.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/cancel_booking.php',
    );

    final response = await http.post(
      uri,
      body: <String, String>{
        'booking_id': bookingId.toString(),
      },
    );

    final data = json.decode(response.body);

    if (!mounted) return;

    if (data is Map && data['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бронирование отменено'),
        ),
      );
      _loadBookings();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ошибка: ${data is Map ? data['message'] : 'не удалось отменить'}',
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (userId == null) return;

    final url =
        'https://sportotekaapp.ru/api/export_bookings_excel.php?user_id=$userId';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось открыть файл'),
      ),
    );
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
                  'Мои бронирования',
                  style: _t(
                    14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ваши активные и ожидающие брони',
                  style: _t(
                    9.6,
                    color: _BookingUi.muted,
                  ),
                ),
              ],
            ),
          ),
          _headerAction(
            'Excel',
            _BookingUi.greenDark,
            _exportToExcel,
          ),
          const SizedBox(width: 5),
          _headerAction(
            'Обновить',
            _BookingUi.green,
            _loadBookings,
          ),
        ],
      ),
    );
  }

  Widget _headerAction(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: _BookingUi.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          child: Row(
            children: <Widget>[
              _dot(
                color,
                size: 4.5,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _t(
                  9.2,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse('${booking['date']}');
    } catch (_) {}

    final formattedDate = parsedDate == null
        ? '${booking['date'] ?? ''}'
        : DateFormat('dd.MM.yyyy').format(parsedDate);

    final status = '${booking['status'] ?? ''}'.toLowerCase();
    final confirmed = status == 'confirmed';
    final statusColor =
        confirmed ? _BookingUi.green : _BookingUi.amber;

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
                statusColor,
                size: 6,
                glow: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${booking['venue_title'] ?? 'Площадка'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    11.8,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _BookingUi.redSoft,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _cancelBooking(
                    int.tryParse('${booking['id']}') ?? 0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: <Widget>[
                        _dot(
                          _BookingUi.red,
                          size: 4,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Отменить',
                          style: _t(
                            8.9,
                            weight: FontWeight.w600,
                            color: _BookingUi.red,
                          ),
                        ),
                      ],
                    ),
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
                formattedDate,
                _BookingUi.greenDark,
              ),
              _pill(
                'Время',
                '${booking['time_slot'] ?? ''}',
                _BookingUi.amber,
              ),
              _pill(
                'Статус',
                confirmed ? 'Подтверждено' : 'Ожидание',
                statusColor,
              ),
            ],
          ),
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
            '$label: ${value.trim().isEmpty ? '—' : value}',
            style: _t(
              9.3,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
              'У вас пока нет бронирований',
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
