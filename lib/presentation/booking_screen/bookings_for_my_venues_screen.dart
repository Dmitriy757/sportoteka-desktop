import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sportoteka/core/utils/pref_utils.dart';

class BookingsForMyVenuesScreen extends StatefulWidget {
  const BookingsForMyVenuesScreen({super.key});

  @override
  State<BookingsForMyVenuesScreen> createState() => _BookingsForMyVenuesScreenState();
}

class _BookingsForMyVenuesScreenState extends State<BookingsForMyVenuesScreen> {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => isLoading = true);
    final ownerId = await PrefUtils.getUserId();

    final uri = Uri.parse('https://sportotekaapp.ru/api/get_venue_bookings_by_owner.php?owner_id=$ownerId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          bookings = List<Map<String, dynamic>>.from(data['bookings']);
        });
      }
    }
    setState(() => isLoading = false);
  }



Widget _buildCustomHeader() {
  return Container(
    padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1E74C4), Color(0xFF007AD9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Бронирования',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'ваших площадок',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ],
    ),
  );
}


  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        _buildCustomHeader(),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : bookings.isEmpty
                  ? const Center(child: Text('Нет бронирований ваших площадок'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            title: Text(
                              booking['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Дата: ${booking['date']}'),
                                Text('Время: ${booking['time_slot']}'),
                                Text('Кто бронировал: ${booking['first_name']} ${booking['last_name']}'),
                                Text('Email: ${booking['email']}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
}


