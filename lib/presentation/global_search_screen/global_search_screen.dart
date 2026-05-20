import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:sportoteka/presentation/player_profile_screen/player_profile_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class GlobalSearchScreen extends StatefulWidget {
  @override
  _GlobalSearchScreenState createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];

  Future<void> _performSearch(String query) async {
    final response = await http.get(Uri.parse(
      "https://sportoteka.ru/api/search.php?query=$query",
    ));

    if (response.statusCode == 200) {
      setState(() {
        _results = json.decode(response.body);
      });
    } else {
      print("Ошибка поиска: ${response.statusCode}");
    }
  }

  void _navigateToDetail(Map<String, dynamic> item) async {
    final int id = item['id'];
    final String name = item['name'];

    switch (item['type']) {
      case 'player':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(player: item),
          ),
        );
        break;

      case 'user':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyProfileScreen(userId: id),
          ),
        );
        break;

      case 'venue':
        final userId = await PrefUtils.getUserId() ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueBookingScreen(
              venueId: id,
              venueTitle: name,
              userId: userId,
            ),
          ),
        );
        break;

      case 'event':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: item),
          ),
        );
        break;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'player':
        return Icons.person;
      case 'user':
        return Icons.account_circle;
      case 'venue':
        return Icons.location_on;
      case 'event':
        return Icons.event;
      default:
        return Icons.help_outline;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'player':
        return Colors.blue;
      case 'user':
        return Colors.green;
      case 'venue':
        return Colors.orange;
      case 'event':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'player':
        return 'Игрок';
      case 'user':
        return 'Пользователь';
      case 'venue':
        return 'Площадка';
      case 'event':
        return 'Мероприятие';
      case 'все':
        return 'Все';
      default:
        return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Поиск")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Поиск игроков, тренеров, площадок...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final type = item['type'];
                      final icon = _getIconForType(type);
                      final color = _getColorForType(type);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_getTypeLabel(type)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _navigateToDetail(item),
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
