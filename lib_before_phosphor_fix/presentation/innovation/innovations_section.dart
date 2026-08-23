// lib/presentation/innovation/innovations_section.dart
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/innovation/screens/ai_technique_screen.dart';
import 'package:sportoteka/presentation/innovation/screens/ar_paint_screen.dart';
import 'package:sportoteka/presentation/innovation/screens/ai_plan_generator_screen.dart';
import 'package:sportoteka/presentation/innovation/screens/quests_screen.dart';
import 'package:sportoteka/presentation/innovation/screens/heatmap_screen.dart';

class InnovationsSection extends StatelessWidget {
  const InnovationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_InnovationItem>[
      _InnovationItem(
        icon: Icons.auto_awesome, // абстрактно про «AI/магия»
        title: "AI-анализ техники",
        subtitle: "Реальный анализ позы (локоть/плечо).",
        gradient: const [Color(0xFF36D1DC), Color(0xFF5B86E5)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiTechniqueScreen())),
      ),
      _InnovationItem(
        icon: Icons.blur_on, // «AR/оверлей»
        title: "AR-Paint цели",
        subtitle: "«Линии краски» поверх камеры + таргеты.",
        gradient: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArPaintScreen())),
      ),
      _InnovationItem(
        icon: Icons.schema_outlined, // план/структура
        title: "AI-план тренировок",
        subtitle: "Автогенерация плана под цель.",
        gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPlanGeneratorScreen())),
      ),
      _InnovationItem(
        icon: Icons.stars_outlined, // ачивки/квесты
        title: "Ежедневные квесты",
        subtitle: "Ачивки, прогресс, награды.",
        gradient: const [Color(0xFFFF512F), Color(0xFFF09819)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestsScreen())),
      ),
      _InnovationItem(
        icon: Icons.bubble_chart, // точки/интенсивность
        title: "Тепловая карта",
        subtitle: "GPS-трек и heatmap на поле.",
        gradient: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatmapScreen())),
      ),
    ];

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
        itemBuilder: (_, i) => _InnovationCard(item: items[i]),
      ),
    );
  }
}

class _InnovationItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _InnovationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

class _InnovationCard extends StatelessWidget {
  final _InnovationItem item;
  const _InnovationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // бейдж «РБ»
            const Text("🇧🇾 Разработано в РБ", style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 10),

            // абстрактная иконка в круге
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Icon(item.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),

            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const Spacer(),
            Row(
              children: const [
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text("Открыть", style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

