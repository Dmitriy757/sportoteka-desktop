import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgLeftLibrary extends StatelessWidget {
  const TgLeftLibrary({
    super.key,
    required this.state,
    this.width = 86,
  });

  final TgState state;
  final double width;

  static const _bg = Color(0xFF1F1F1F);
  static const _bd = Color(0xFF141414);

  // ⚽️ Твои ассеты (добавляй сколько хочешь)
  static const _items = <_LibItem>[
    _LibItem("Игрок", "assets/training/stamps/players/player.png"),
    _LibItem("Вратарь", "assets/training/stamps/players/goalkeeper.png"),
    _LibItem("Соперник", "assets/training/stamps/players/opponent.png"),
    _LibItem("Мяч", "assets/training/stamps/props/ball.png"),
    _LibItem("Конус", "assets/training/stamps/props/cone.png"),
    _LibItem("Фишка", "assets/training/stamps/props/marker.png"),
    _LibItem("Барьер", "assets/training/stamps/props/hurdle.png"),
    _LibItem("Лестница", "assets/training/stamps/props/ladder.png"),
    _LibItem("Манекен", "assets/training/stamps/props/dummy.png"),
    _LibItem("Ворота", "assets/training/stamps/props/goal.png"),
    _LibItem("Скамейка", "assets/training/stamps/props/bench.png"),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return Container(
          width: width,
          decoration: const BoxDecoration(
            color: _bg,
            border: Border(right: BorderSide(color: _bd, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.category_outlined, color: Colors.white, size: 20),
                const SizedBox(height: 6),
                const Text(
                  "Объекты",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 14),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final active = state.activeStampAsset == it.asset && state.tool == TgTool.stamp;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            state.setActiveStamp(it.asset);
                            state.setTool(TgTool.stamp);
                          },
                          child: Container(
                            height: 62,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF2B2B2B) : const Color(0xFF242424),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: active ? const Color(0xFF00A750) : const Color(0xFF333333),
                                width: active ? 1.6 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Image.asset(
                                it.asset,
                                width: 34,
                                height: 34,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 8),

                _miniBtn(
                  icon: Icons.undo_rounded,
                  enabled: state.canUndo,
                  onTap: state.canUndo ? state.undo : null,
                  tooltip: "Undo",
                ),
                _miniBtn(
                  icon: Icons.redo_rounded,
                  enabled: state.canRedo,
                  onTap: state.canRedo ? state.redo : null,
                  tooltip: "Redo",
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 56,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
          ),
        ),
      ),
    );
  }
}

class _LibItem {
  final String title;
  final String asset;
  const _LibItem(this.title, this.asset);
}
