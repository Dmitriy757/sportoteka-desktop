
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../player_profile_screen/player_profile_screen.dart';

class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Профиль')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Профиль игрока'),
            onTap: () {
              Get.to(() => PlayerProfileScreen(player: {
                "fullName": "Иван Петров",
                "age": "17",
                "birthDate": "2007-04-01",
                "position": "Вратарь",
                "club": "ФК Минск",
                "number": "1",
                "height": "185",
                "weight": "75",
                "achievements": "Лучший вратарь сезона 2024",
                "photo": "", // можно вставить ссылку на фото
              }));
            },
          ),
          ListTile(
            leading: Icon(Icons.emoji_events),
            title: Text('Достижения'),
            onTap: () {
              Get.snackbar('Достижения', 'Раздел в разработке');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Настройки'),
            onTap: () {
              Get.snackbar('Настройки', 'Раздел в разработке');
            },
          ),
        ],
      ),
    );
  }
}
