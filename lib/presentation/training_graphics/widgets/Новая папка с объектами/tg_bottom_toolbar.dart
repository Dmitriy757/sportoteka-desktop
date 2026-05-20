import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgBottomToolbar extends StatelessWidget {
  final TgState state;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPlayers;

  const TgBottomToolbar({
    super.key,
    required this.state,
    required this.onOpenSettings,
    required this.onOpenPlayers,
  });

  @override
  Widget build(BuildContext context) {
    Widget toolBtn({
      required IconData icon,
      required String label,
      required TgTool tool,
    }) {
      final active = state.tool == tool;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => state.setTool(tool),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE7F3EA) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? const Color(0xFF00A750) : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: const Color(0xFF2E2E2E)),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF2E2E2E),
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget actionBtn({
      required IconData icon,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      return Tooltip(
        message: tooltip ?? "",
        child: Material(
          color: const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 22, color: const Color(0xFF2E2E2E)),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: const [
            BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x14000000)),
          ],
        ),
        child: Row(
          children: [
            toolBtn(icon: Icons.pan_tool_alt_outlined, label: "Выбор", tool: TgTool.select),
            toolBtn(icon: Icons.arrow_forward_outlined, label: "Линия", tool: TgTool.line),
            toolBtn(icon: Icons.text_fields, label: "Текст", tool: TgTool.text),
            toolBtn(icon: Icons.crop_square_outlined, label: "Квадрат", tool: TgTool.rect),
            toolBtn(icon: Icons.circle_outlined, label: "Круг", tool: TgTool.circle),

            
            const SizedBox(width: 8),
            actionBtn(icon: Icons.groups_2_outlined, onTap: onOpenPlayers, tooltip: "Библиотека объектов"),
            
          ],
        ),
      ),
    );
  }
}
