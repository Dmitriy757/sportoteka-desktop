import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgLeftToolbar extends StatelessWidget {
  const TgLeftToolbar({
    super.key,
    required this.state,
    required this.onZoomToSelection,
    required this.onResetView,
  });

  final TgState state;
  final VoidCallback onZoomToSelection;
  final VoidCallback onResetView;

  // iPad minimal palette
  static const _bg = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE5E7EB); // light gray
  static const _divider = Color(0xFFF1F5F9); // super light
  static const _icon = Color(0xFF6B7280); // gray
  static const _iconActive = Color(0xFF111827); // near black
  static const _activeBg = Color(0xFFF3F4F6); // light pill
  static const _activeMark = Color(0xFFCBD5E1); // subtle side mark

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return Container(
          width: 48, // ✅ ещё уже
          decoration: const BoxDecoration(
            color: _bg,
            border: Border(
              right: BorderSide(color: _border, width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              _toolBtn(
                icon: Icons.mouse,
                active: state.tool == TgTool.select,
                tooltip: "Выбор",
                onTap: () => state.setTool(TgTool.select),
              ),
              _toolBtn(
                icon: Icons.horizontal_rule_rounded,
                active: state.tool == TgTool.line,
                tooltip: "Линия",
                onTap: () => state.setTool(TgTool.line),
              ),
              _toolBtn(
                icon: Icons.waves_rounded, // ✅ волна
                active: state.tool == TgTool.wavy,
                tooltip: "Волна",
                onTap: () => state.setTool(TgTool.wavy),
              ),
  //            _toolBtn(
  //icon: Icons.timeline_rounded,  // Иконка молнии для зигзага
  //active: state.tool == TgTool.zigzag,
  //tooltip: "Зигзаг",
  //onTap: () => state.setTool(TgTool.zigzag),
//),
//_toolBtn(
  //icon: Icons.bolt_rounded,  // Можно заменить на другую иконку
  //active: state.tool == TgTool.spring,
  //tooltip: "Пружинка",
  //onTap: () => state.setTool(TgTool.spring),
//),
//_toolBtn(
 // icon: Icons.rotate_right_rounded,  // Иконка для спирали
 // active: state.tool == TgTool.spiral,
 // tooltip: "Спираль",
  //onTap: () => state.setTool(TgTool.spiral),
//),
              _toolBtn(
                icon: Icons.crop_square_rounded,
                active: state.tool == TgTool.rect,
                tooltip: "Прямоугольник",
                onTap: () => state.setTool(TgTool.rect),
              ),
              _toolBtn(
                icon: Icons.circle_outlined,
                active: state.tool == TgTool.circle,
                tooltip: "Круг",
                onTap: () => state.setTool(TgTool.circle),
              ),
              _toolBtn(
                icon: Icons.text_fields_rounded,
                active: state.tool == TgTool.text,
                tooltip: "Текст",
                onTap: () => state.setTool(TgTool.text),
              ),
              _toolBtn(
                icon: Icons.person_rounded,
                active: state.tool == TgTool.stamp,
                tooltip: "Объекты",
                onTap: () => state.setTool(TgTool.stamp),
              ),

              const SizedBox(height: 10),
              _hr(),

              // ===== 3D КНОПКИ =====
              _toolBtn(
                icon: state.is3DMode ? Icons.threed_rotation : Icons.threesixty_rounded,
                active: state.is3DMode,
                tooltip: state.is3DMode ? "Выключить 3D" : "Включить 3D",
                onTap: () => state.toggle3DMode(),
              ),
              
              _toolBtn(
                icon: Icons.settings_overscan_rounded,
                active: false,
                tooltip: "Сброс 3D",
                onTap: () => state.reset3D(),
              ),

              const SizedBox(height: 10),
              _hr(),

              _toolBtn(
                icon: Icons.undo_rounded,
                active: false,
                tooltip: "Undo",
                onTap: state.canUndo ? state.undo : null,
              ),
              _toolBtn(
                icon: Icons.redo_rounded,
                active: false,
                tooltip: "Redo",
                onTap: state.canRedo ? state.redo : null,
              ),

              const SizedBox(height: 10),
              _hr(),

              _toolBtn(
                icon: state.gridEnabled ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                active: state.gridEnabled,
                tooltip: "Сетка",
                onTap: state.toggleGrid,
              ),
              _toolBtn(
                icon: state.lockViewportGestures ? Icons.lock_rounded : Icons.lock_open_rounded,
                active: state.lockViewportGestures,
                tooltip: "Lock view",
                onTap: () => state.setLockViewport(!state.lockViewportGestures),
              ),

              const Spacer(),
              _hr(),

              _toolBtn(
                icon: Icons.center_focus_strong_rounded,
                active: false,
                tooltip: "Zoom",
                onTap: onZoomToSelection,
              ),
              _toolBtn(
                icon: Icons.refresh_rounded,
                active: false,
                tooltip: "Reset",
                onTap: onResetView,
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _hr() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: _divider,
      );

  Widget _toolBtn({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final iconColor = active ? _iconActive : _icon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36, // ✅ компактнее
            decoration: BoxDecoration(
              color: active ? _activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                // ✅ тонкая метка слева, как в iPad UI
                if (active)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 3,
                      height: 18,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: _activeMark,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                Center(
                  child: Icon(icon, size: 18, color: iconColor), // ✅ меньше иконки
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}