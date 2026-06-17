// lib/presentation/innovation/screens/ai_plan_generator_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sportoteka/data/innovation_api.dart';

class AiPlanGeneratorScreen extends StatefulWidget {
  const AiPlanGeneratorScreen({super.key});
  @override
  State<AiPlanGeneratorScreen> createState() => _AiPlanGeneratorScreenState();
}

class _AiPlanGeneratorScreenState extends State<AiPlanGeneratorScreen> {
  String _goal = 'Выносливость (футбол)';
  int _sessions = 4;
  int _weeks = 6;
  bool _hasGym = true;
  bool _hasField = true;
  List<String> _plan = [];

  void _generate() {
    final plan = <String>[];
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    final endurance = [
      'Интервалы 6×400м (80–90% ЧСС) + заминка',
      'Фартлек 30 мин (1/1 мин) + координация',
      'Кросс 6–8 км Z2 + растяжка',
      'Игра 5×5: 4×6 мин',
      'Лестница + прыжки 3×8',
    ];
    final strength = [
      'Силовой: присед 4×6, жим 4×6, тяга 3×8',
      'Кор: планка 3×60с, скручивания 3×15',
      'Плиометрика: прыжки 5×6',
      'Тяга 4×5 + ягодичный мост 3×10',
    ];
    final skills = [
      'Удары 8×10 + передачи 6×12',
      'Дриблинг 5×1 мин + игра 3×8 мин',
      'Стандарты: 15 штрафных + 15 угловых',
      'Контроль мяча 3×8 мин',
    ];

    List<String> lib;
    if (_goal.contains('сил')) lib = [...strength, if (_hasField) ...skills.take(2)];
    else if (_goal.contains('скорост')) lib = ['Спринты 8×30м', 'Лестница координации', 'Плио 5×6', ...skills];
    else lib = [...endurance, ...skills];

    int idx = 0;
    for (int w = 1; w <= _weeks; w++) {
      final phase = _phaseForWeek(w, _weeks);
      plan.add('Неделя $w [$phase]');
      final used = _chooseDays(_sessions, days);
      for (final d in used) {
        final item = lib[idx % lib.length];
        final gymNote = _hasGym ? ' + зал (кор/стабильность 12–15 мин)' : '';
        final fieldNote = _hasField ? ' + поле (техника 10–15 мин)' : '';
        plan.add('  $d: $item$gymNote$fieldNote');
        idx++;
      }
      plan.add('');
    }
    setState(() => _plan = plan);
  }

  String _phaseForWeek(int w, int total) {
    final p = w / total;
    if (p < 0.5) return 'BASE';
    if (p < 0.8) return 'BUILD';
    if (p < 0.95) return 'PEAK';
    return 'DELOAD';
  }

  List<String> _chooseDays(int s, List<String> base) {
    if (s >= base.length) return base;
    if (s <= 0) return [];
    final step = (base.length / s).floor();
    final out = <String>[];
    int i = 0;
    while (out.length < s && i < base.length) {
      out.add(base[i]); i += step;
    }
    for (final d in base) {
      if (out.length >= s) break;
      if (!out.contains(d)) out.add(d);
    }
    return out.take(s).toList();
  }

  Future<void> _share() async {
    if (_plan.isEmpty) _generate();
    final text = [
      '📅 AI-план тренировок (🇧🇾 РБ — Sportoteka)',
      'Цель: $_goal | Сессий/нед: $_sessions | Недель: $_weeks | Зал: ${_hasGym ? "да" : "нет"} | Поле: ${_hasField ? "да" : "нет"}',
      '',
      ..._plan,
    ].join('\n');
    await Share.share(text);
  }

  Future<void> _exportPdf() async {
    if (_plan.isEmpty) _generate();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text('AI-план тренировок', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('🇧🇾 Разработано в РБ — Sportoteka'),
          pw.SizedBox(height: 12),
          pw.Text('Цель: $_goal | Сессий/нед: $_sessions | Недель: $_weeks | Зал: ${_hasGym ? "да" : "нет"} | Поле: ${_hasField ? "да" : "нет"}'),
          pw.SizedBox(height: 12),
          pw.Text(_plan.join('\n')),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _exportIcs() async {
    if (_plan.isEmpty) _generate();
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Sportoteka//AI Plan//BY');

    int week = 0;
    for (final line in _plan) {
      if (line.startsWith('Неделя')) { week++; continue; }
      if (line.trim().isEmpty || !line.contains(':')) continue;
      final parts = line.split(':');
      final dayRu = parts.first.trim();
      final summary = parts.sublist(1).join(':').trim();
      final weekday = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].indexOf(dayRu);
      if (weekday < 0) continue;

      final start = now.add(Duration(days: (week-1)*7 + weekday));
      final dt = DateTime(start.year, start.month, start.day, 19, 0);
      final dtEnd = dt.add(const Duration(hours: 1));
      String fmt(DateTime d) => d.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':','').split('.').first+'Z';

      buf.writeln('BEGIN:VEVENT');
      buf.writeln('UID:${dt.millisecondsSinceEpoch}@sportoteka');
      buf.writeln('DTSTAMP:${fmt(DateTime.now())}');
      buf.writeln('DTSTART:${fmt(dt)}');
      buf.writeln('DTEND:${fmt(dtEnd)}');
      buf.writeln('SUMMARY:${summary}');
      buf.writeln('END:VEVENT');
    }

    buf.writeln('END:VCALENDAR');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/plan_${DateTime.now().millisecondsSinceEpoch}.ics');
    await file.writeAsBytes(utf8.encode(buf.toString()), flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Календарь тренировок (🇧🇾 РБ — Sportoteka)');
  }

  Future<void> _saveToServer() async {
    try {
      if (_plan.isEmpty) _generate();
      final id = await InnovationApi.saveTrainingPlan(
        goal: _goal,
        sessionsPerWeek: _sessions,
        weeks: _weeks,
        hasGym: _hasGym,
        hasField: _hasField,
        planText: _plan.join('\n'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('План сохранён (ID $id)')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI-генератор планов'), actions: [
        IconButton(icon: const Icon(Icons.save), onPressed: _saveToServer),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Цель', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _goal,
            items: const [
              DropdownMenuItem(value: 'Выносливость (футбол)', child: Text('Выносливость (футбол)')),
              DropdownMenuItem(value: 'Силовые качества', child: Text('Силовые качества')),
              DropdownMenuItem(value: 'Скоростная выносливость', child: Text('Скоростная выносливость')),
            ],
            onChanged: (v) => setState(() => _goal = v ?? _goal),
          ),
          const SizedBox(height: 16),
          _LabeledSlider(label: 'Сессий в неделю: $_sessions', value: _sessions.toDouble(), min: 2, max: 7,
            onChanged: (v) => setState(() => _sessions = v.round())),
          _LabeledSlider(label: 'Длительность (нед.): $_weeks', value: _weeks.toDouble(), min: 4, max: 12,
            onChanged: (v) => setState(() => _weeks = v.round())),
          SwitchListTile(title: const Text('Есть доступ в зал'), value: _hasGym, onChanged: (v) => setState(() => _hasGym = v)),
          SwitchListTile(title: const Text('Есть поле/площадка'), value: _hasField, onChanged: (v) => setState(() => _hasField = v)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome), label: const Text('Сгенерировать')),
              OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Поделиться')),
              OutlinedButton.icon(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
              OutlinedButton.icon(onPressed: _exportIcs, icon: const Icon(Icons.event), label: const Text('Календарь')),
            ],
          ),
          const SizedBox(height: 16),
          if (_plan.isNotEmpty)
            Card(
              elevation: 0, color: Colors.grey.shade50,
              child: Padding(padding: const EdgeInsets.all(12.0), child: Text(_plan.join('\n'))),
            ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerRight, child: Text('🇧🇾 Разработано в РБ — Sportoteka', style: TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label; final double value; final double min; final double max; final ValueChanged<double> onChanged;
  const _LabeledSlider({required this.label, required this.value, required this.min, required this.max, required this.onChanged, super.key});
  @override
  Widget build(BuildContext context) {
    final divisions = (max - min).round().clamp(1, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }
}
