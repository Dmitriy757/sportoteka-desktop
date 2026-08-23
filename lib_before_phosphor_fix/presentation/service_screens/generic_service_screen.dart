// шаблон экрана с Dynamo Minsk style
import 'package:flutter/material.dart';

class GenericServiceScreen extends StatelessWidget {
  final String title;
  final String sport;

  const GenericServiceScreen({super.key, required this.title, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF005AAB),
        title: Text('$title • $sport'),
      ),
      body: Center(
        child: Text(
          'Страница "$title" для вида спорта "$sport" в разработке.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
    );
  }
}

// Примеры использования:
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => const GenericServiceScreen(title: 'Статистика', sport: 'Футбол')));
// Можно переиспользовать один экран для всех сервисов




