import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

class TeamPlayersScreen extends StatefulWidget {
  final int teamId;

  const TeamPlayersScreen({Key? key, required this.teamId}) : super(key: key);

  @override
  State<TeamPlayersScreen> createState() => _TeamPlayersScreenState();
}

class _TeamPlayersScreenState extends State<TeamPlayersScreen> {
  List<dynamic> players = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchPlayers();
  }

  Future<void> fetchPlayers() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://sportotekaapp.ru/api/get_players_by_team.php?team_id=${widget.teamId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // Отладочная информация
        debugPrint('=== API RESPONSE ===');
        debugPrint('Team ID: ${widget.teamId}');
        debugPrint('Response status: ${data['status']}');
        debugPrint('Players count: ${data['players']?.length ?? 0}');

        if (data['status'] == 'success') {
          // Проверяем структуру данных первого игрока
          if (data['players'] is List && data['players'].isNotEmpty) {
            final firstPlayer = data['players'][0];
            debugPrint('First player keys: ${firstPlayer.keys.toList()}');
            debugPrint('First player has user_id: ${firstPlayer['user_id'] != null}');
            debugPrint('First player user_id value: ${firstPlayer['user_id']}');
            debugPrint('First player id value: ${firstPlayer['id']}');
          }

          setState(() {
            players = data['players'];
            isLoading = false;
          });
        } else {
          setState(() {
            error = data['message'] ?? 'Ошибка загрузки';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Ошибка сервера: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Ошибка сети: $e';
        isLoading = false;
      });
    }
  }

  // Вспомогательная функция для парсинга ID
  int? _parseUserId(dynamic rawId) {
    if (rawId == null) return null;
    
    try {
      if (rawId is int) return rawId;
      if (rawId is String) {
        final clean = rawId.trim();
        if (clean.isEmpty) return null;
        return int.tryParse(clean);
      }
      return int.tryParse(rawId.toString());
    } catch (e) {
      debugPrint('Error parsing ID: $e');
      return null;
    }
  }

  void _openPlayerProfile(dynamic playerData, String playerName) {
    debugPrint('=== OPENING PLAYER PROFILE ===');
    debugPrint('Player name: $playerName');
    debugPrint('Team ID: ${widget.teamId}');
    
    // ИСПРАВЛЕНИЕ: Используем user_id из API (теперь он есть!)
    final rawUserId = playerData['user_id'];
    debugPrint('Raw user_id from API: $rawUserId (type: ${rawUserId.runtimeType})');
    
    // Парсим user_id
    int? userId = _parseUserId(rawUserId);
    
    debugPrint('Parsed userId: $userId');
    
    if (userId != null && userId > 0) {
      // УСПЕХ: открываем профиль пользователя
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyProfileScreen(userId: userId),
        ),
      ).then((_) {
        debugPrint('Returned from profile screen');
      });
    } else {
      // Если user_id нет или он некорректен
      debugPrint('ERROR: No valid user_id found');
      debugPrint('Player data: $playerData');
      
      // Показываем информационное сообщение
      _showProfileUnavailableDialog(playerName);
    }
  }

  void _showProfileUnavailableDialog(String playerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Профиль недоступен'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Профиль игрока "$playerName" пока недоступен.'),
            const SizedBox(height: 16),
            const Text(
              'Это может быть потому что:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Игрок не зарегистрирован в приложении'),
            const Text('• Профиль находится в разработке'),
            const Text('• Нет связи с пользовательским аккаунтом'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  String? _getPhotoUrl(dynamic photoData) {
    if (photoData == null) return null;
    final photo = photoData.toString().trim();
    if (photo.isEmpty) return null;
    
    // Проверяем различные варианты URL
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return photo;
    } else if (photo.contains('/')) {
      // Если это уже путь
      return 'https://sportotekaapp.ru/$photo';
    } else {
      // Если только имя файла
      return 'https://sportotekaapp.ru/uploads/$photo';
    }
  }

  Widget _buildPlayerAvatar(Map<String, dynamic> player) {
    final photo = player['photo_url'] ?? player['photo'];
    final String? photoUrl = _getPhotoUrl(photo);
    
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey[200],
      backgroundImage: photoUrl != null
          ? NetworkImage(photoUrl)
          : const AssetImage('assets/images/user_placeholder.png') as ImageProvider,
      child: photoUrl == null
          ? const Icon(Icons.person, size: 28, color: Colors.grey)
          : null,
    );
  }

  Widget _buildPlayerInfo(String position, String jerseyNumber) {
    final List<Widget> infoWidgets = [];
    
    if (position.isNotEmpty) {
      infoWidgets.add(
        Text(
          position,
          style: const TextStyle(fontSize: 14),
        ),
      );
    }
    
    if (jerseyNumber.isNotEmpty) {
      infoWidgets.add(
        Text(
          '№ $jerseyNumber',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoWidgets,
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player, int index) {
    final firstName = player['first_name'] ?? '';
    final lastName = player['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final position = player['position'] ?? '';
    final jerseyNumber = player['jersey_number'] ?? player['number'] ?? '';
    final userId = player['user_id'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ListTile(
        onTap: () {
          _openPlayerProfile(player, fullName);
        },
        leading: _buildPlayerAvatar(player),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullName.isNotEmpty ? fullName : 'Игрок',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            // Отладочная информация (можно скрыть в продакшене)
            if (userId != null)
              Text(
                'ID профиля: $userId',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        subtitle: _buildPlayerInfo(position, jerseyNumber),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Состав команды'),
        backgroundColor: const Color(0xFF1E74C4),
        foregroundColor: Colors.white,
        actions: [
          // Кнопка обновления
          IconButton(
            onPressed: fetchPlayers,
            icon: const Icon(Icons.refresh),
          ),
          // Кнопка отладки
          IconButton(
            onPressed: () {
              debugPrint('=== DEBUG INFO ===');
              debugPrint('Team ID: ${widget.teamId}');
              debugPrint('Players loaded: ${players.length}');
              
              if (players.isNotEmpty) {
                debugPrint('First player data:');
                final first = players[0];
                first.forEach((key, value) {
                  debugPrint('  $key: $value (${value.runtimeType})');
                });
              }
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(error, 
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: fetchPlayers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E74C4),
                          ),
                          child: const Text('Повторить', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : players.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'В команде нет игроков',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: fetchPlayers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E74C4),
                            ),
                            child: const Text('Обновить', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchPlayers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          return _buildPlayerCard(players[index], index);
                        },
                      ),
                    ),
    );
  }
}