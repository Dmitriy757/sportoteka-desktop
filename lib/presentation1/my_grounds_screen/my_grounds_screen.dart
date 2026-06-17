import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sportoteka/presentation/booking_screen/add_venue_screen.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/booking_screen/venue_detail_screen.dart';


class MyGroundsScreen extends StatefulWidget {
  const MyGroundsScreen({super.key});

  @override
  State<MyGroundsScreen> createState() => _MyGroundsScreenState();
}

class _MyGroundsScreenState extends State<MyGroundsScreen> {
  List<Map<String, dynamic>> _myVenues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyVenues();
  }

  Future<void> _loadMyVenues() async {
    final userId = await PrefUtils.getUserId();
    final response = await http.get(Uri.parse(
        'https://sportoteka.by/api/get_user_venues.php?user_id=$userId'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _myVenues = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить площадки')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои площадки"),
        backgroundColor: const Color(0xFF1E74C4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myVenues.isEmpty
              ? const Center(child: Text("У вас пока нет добавленных площадок"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _myVenues.length,
                  itemBuilder: (context, index) {
                    final venue = _myVenues[index];
                    return _buildVenueCard(venue);
                  },
                ),
      floatingActionButton: FloatingActionButton(
  onPressed: () async {
    final userId = await PrefUtils.getUserId();
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddVenueScreen(userId: userId),
        ),
      ).then((_) => _loadMyVenues());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
    }
  },
  backgroundColor: const Color(0xFF1E74C4),
  child: const Icon(Icons.add),
),
    );
  }

 Widget _buildVenueCard(Map<String, dynamic> venue) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VenueDetailScreen(venue: venue),
        ),
      );
    },
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venue['image_url'] != null && venue['image_url'].isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    venue['image_url'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue['title'] ?? 'Без названия',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(venue['address'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      venue['conditions'] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Иконка редактирования
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF1E74C4)),
              onPressed: () async {
                final userId = await PrefUtils.getUserId();
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddVenueScreen(
                        userId: userId,
                        venue: venue, // передаём всю информацию
                      ),
                    ),
                  ).then((_) => _loadMyVenues());
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}

}
