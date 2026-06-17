// lib/presentation/training_graphics/widgets/tg_players_picker_sheet.dart
import 'package:flutter/material.dart';
import '../training_graphics_state.dart';

class TgPlayersPickerSheet extends StatelessWidget {
  const TgPlayersPickerSheet({
    super.key,
    required this.state,
  });

  final TgState state;

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF00A750);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Color(0x22000000)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Библиотека объектов",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ✅ ОСТАВЛЯЕМ ТОЛЬКО: мужчины / женщины / тренеры / инвентарь

              _ExpSection(
                title: "Игроки (мужчины)",
                startOpen: true,
                children: [
                  _Grid(
                    items: const [
                      _StampItem("Бег", "assets/training/stamps/player_m/run.png"),
                      _StampItem("Пас", "assets/training/stamps/player_m/pass.png"),
                      _StampItem("Стоит", "assets/training/stamps/player_m/stand.png"),
                      _StampItem("Прыжок", "assets/training/stamps/player_m/jump.png"),
                      _StampItem("Вратарь", "assets/training/stamps/player_m/goalkeeper.png"),
                    ],
                    onPick: (asset) => Navigator.pop(context, asset),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _ExpSection(
                title: "Игроки (женщины)",
                startOpen: false,
                children: [
                  _Grid(
                    items: const [
                      _StampItem("Бег", "assets/training/stamps/player_f/run.png"),
                      _StampItem("Пас", "assets/training/stamps/player_f/pass.png"),
                      _StampItem("Стоит", "assets/training/stamps/player_f/stand.png"),
                      _StampItem("Прыжок", "assets/training/stamps/player_f/jump.png"),
                      _StampItem("Вратарь", "assets/training/stamps/player_f/goalkeeper.png"),
                    ],
                    onPick: (asset) => Navigator.pop(context, asset),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _ExpSection(
                title: "Тренеры",
                startOpen: false,
                children: [
                  _Grid(
                    items: const [
                      _StampItem("Тренер", "assets/training/stamps/coach/male.png"),
                      _StampItem("Тренер (жен)", "assets/training/stamps/coach/female.png"),
                    ],
                    onPick: (asset) => Navigator.pop(context, asset),
                  ),
                ],
              ),

              const SizedBox(height: 12),

             _ExpSection(
  title: "Инвентарь / Маркеры",
  startOpen: false,
  children: [
    _Grid(
      items: const [
        // База
        _StampItem("Мяч", "assets/training/stamps/props/ball.png"),
        _StampItem("Конус", "assets/training/stamps/props/cone.png"),
        _StampItem("Фишка", "assets/training/stamps/props/marker.png"),
        _StampItem("Барьер", "assets/training/stamps/props/hurdle.png"),

        // Ворота (как на скрине: Tor / Tor gekippt / Minitor / Minitor gekippt / Hallentor)
        _StampItem("Ворота", "assets/training/stamps/props/goal.png"),
        _StampItem("Ворота (наклонные)", "assets/training/stamps/props/goal_tilt.png"),
        _StampItem("Мини-ворота", "assets/training/stamps/props/mini_goal.png"),
        _StampItem("Мини-ворота (наклонные)", "assets/training/stamps/props/mini_goal_tilt.png"),
        _StampItem("Гандбольные ворота", "assets/training/stamps/props/handball_goal.png"),

        // Остальное (как на скрине: Dummy / Leiter / Stange / Ring / Matte / Flagge / Flagge mit Fuß / Bank)
        _StampItem("Манекен", "assets/training/stamps/props/dummy.png"),
        _StampItem("Координационная лестница", "assets/training/stamps/props/ladder.png"),
        _StampItem("Стойка", "assets/training/stamps/props/pole.png"),
        _StampItem("Обруч", "assets/training/stamps/props/ring.png"),
        _StampItem("Мат", "assets/training/stamps/props/mat.png"),
        _StampItem("Флажок", "assets/training/stamps/props/flag.png"),
        _StampItem("Флажок на основании", "assets/training/stamps/props/flag_base.png"),
        _StampItem("Скамейка", "assets/training/stamps/props/bench.png"),
      ],
      onPick: (asset) => Navigator.pop(context, asset),
    ),
  ],
),

            ],
          ),
        ),
      ),
    );
  }
}

// ===================== EXP SECTIONS =====================

class _ExpSection extends StatefulWidget {
  const _ExpSection({
    required this.title,
    required this.children,
    this.startOpen = true,
  });

  final String title;
  final List<Widget> children;
  final bool startOpen;

  @override
  State<_ExpSection> createState() => _ExpSectionState();
}

class _ExpSectionState extends State<_ExpSection> {
  late bool open;

  @override
  void initState() {
    super.initState();
    open = widget.startOpen;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: widget.children),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== GRID =====================

class _StampItem {
  final String title;
  final String asset;
  const _StampItem(this.title, this.asset);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onPick});
  final List<_StampItem> items;
  final void Function(String asset) onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          onTap: () => onPick(it.asset),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(blurRadius: 14, offset: Offset(0, 8), color: Color(0x14000000)),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Image.asset(
                      it.asset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
