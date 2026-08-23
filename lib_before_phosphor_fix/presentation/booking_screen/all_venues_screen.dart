import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AllVenuesScreen extends StatefulWidget {
  const AllVenuesScreen({super.key});

  @override
  State<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends State<AllVenuesScreen> {
  String selectedSport = 'Все';
  late Future<List<Map<String, dynamic>>> _futureVenues;

  final List<String> sports = ['Все', 'Футбол', 'Баскетбол', 'Волейбол', 'Теннис', 'Хоккей'];

  @override
  void initState() {
    super.initState();
    _futureVenues = _fetchVenues();
  }

  Future<List<Map<String, dynamic>>> _fetchVenues() async {
    final uri = Uri.parse('https://sportotekaapp.ru/api/get_venues.php${selectedSport != 'Все' ? '?sport=$selectedSport' : ''}');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['venues']);
      }
    }
    return [];
  }

  void _onSportChanged(String sport) {
    setState(() {
      selectedSport = sport;
      _futureVenues = _fetchVenues();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все площадки'),
        backgroundColor: const Color(0xFF1E74C4),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: sports.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final sport = sports[index];
                return ChoiceChip(
                  label: Text(sport),
                  selected: selectedSport == sport,
                  selectedColor: const Color(0xFF1E74C4),
                  onSelected: (_) => _onSportChanged(sport),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureVenues,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Ошибка загрузки данных'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Нет доступных площадок'));
                }

                final venues = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: venues.length,
                  itemBuilder: (context, index) {
                    final venue = venues[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          venue['image_path'] != null && venue['image_path'].toString().isNotEmpty
                              ? Image.network(venue['image_path'], height: 180, width: double.infinity, fit: BoxFit.cover)
                              : Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Center(child: Text('Без изображения')),
                                ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(venue['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(venue['address'], style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text('Условия: ${venue['conditions']}'),
                                const SizedBox(height: 4),
                                Text(venue['description']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
