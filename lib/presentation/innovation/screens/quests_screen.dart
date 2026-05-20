// lib/presentation/innovation/screens/quests_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportoteka/data/innovation_api.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});
  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  late Future<void> _initFuture;
  final _quests = <_Quest>[
    _Quest('Пробежать 5 км', 'Бег в Z2/З3', 'run5k'),
    _Quest('Забить 10 голов', 'Удары по воротам 10×', 'goals10'),
    _Quest('50 отжиманий', 'Можно 5×10', 'pushups50'),
  ];
  final _done = <String, bool>{};

  int _streak = 0;
  String get _dateKey => DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

  @override
  void initState() {
    super.initState();
    _initFuture = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final q in _quests) {
      _done[q.key] = prefs.getBool('quest:${_dateKey}:${q.key}') ?? false;
    }
    await _recalcStreak();
    setState(() {});
  }

  bool _allDoneToday() => _quests.every((q) => _done[q.key] == true);

  Future<void> _toggle(_Quest q, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quest:${_dateKey}:${q.key}', v);
    setState(() => _done[q.key] = v);
    await _recalcStreak();
    await _saveToServer();
  }

  Future<void> _recalcStreak() async {
    final prefs = await SharedPreferences.getInstance();
    // помечаем сегодняшний день
    await prefs.setBool('quests:day:${_dateKey}', _allDoneToday());
    // считаем streak назад от сегодня
    int s = 0; DateTime d = DateTime.now();
    while (true) {
      final k = d.toIso8601String().substring(0,10);
      final v = prefs.getBool('quests:day:$k') ?? false;
      if (v) { s++; d = d.subtract(const Duration(days: 1)); } else { break; }
    }
    setState(() => _streak = s);
  }

  Future<void> _saveToServer() async {
    try {
      final tasks = { for (final q in _quests) q.key : (_done[q.key] == true) };
      await InnovationApi.upsertQuestDay(
        dateKey: _dateKey,
        completed: _allDoneToday(),
        tasks: tasks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Прогресс сохранён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔥 Ежедневные квесты')),
      body: FutureBuilder(
        future: _initFuture,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Серия: $_streak дней', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _quests.isEmpty ? 0 : _quests.where((q) => _done[q.key] == true).length / _quests.length, minHeight: 8),
              const SizedBox(height: 12),
              ..._quests.map((q) {
                final v = _done[q.key] == true;
                return Card(
                  child: CheckboxListTile(
                    title: Text(q.title),
                    subtitle: Text(q.subtitle),
                    value: v,
                    onChanged: (nv) => _toggle(q, nv ?? false),
                    secondary: Icon(v ? Icons.emoji_events : Icons.flag),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('🇧🇾 Разработано в РБ — Sportoteka', style: TextStyle(color: Colors.black54))),
            ],
          );
        },
      ),
    );
  }
}

class _Quest {
  final String title; final String subtitle; final String key;
  _Quest(this.title, this.subtitle, this.key);
}
