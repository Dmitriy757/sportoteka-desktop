import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgLeftToolbar extends StatelessWidget {
  const TgLeftToolbar({
    super.key,
    required this.state,
    required this.onZoomToSelection,
    required this.onResetView,
    required this.onCloseEditor,
    required this.onOpenObjects,
    required this.onOpenLayers,
    required this.onOpenProperties,
    required this.onOpenTactics,
  });

  final TgState state;
  final VoidCallback onZoomToSelection;
  final VoidCallback onResetView;
  final VoidCallback onCloseEditor;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenLayers;
  final VoidCallback onOpenProperties;
  final VoidCallback onOpenTactics;

  static const _bg = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFFAFBFC);
  static const _border = Color(0xFFE9EDF2);
  static const _text = Color(0xFF0B1220);
  static const _muted = Color(0xFF667085);
  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFEFFBF5);
  static const _danger = Color(0xFFE11D48);
  static const _font = 'Inter';
  static const _railWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return Container(
          width: _railWidth,
          decoration: const BoxDecoration(
            color: _bg,
            border: Border(right: BorderSide(color: _border, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 5),
                _brandMark(),
                const SizedBox(height: 5),
                _navButton(
                  icon: Icons.ads_click_rounded,
                  label: 'Выбор',
                  active: state.tool == TgTool.select,
                  onTap: () => state.setTool(TgTool.select),
                  showDot: true,
                ),
                _navButton(
                  icon: Icons.category_outlined,
                  label: 'Объекты',
                  active: state.tool == TgTool.stamp,
                  onTap: onOpenObjects,
                ),
                _navButton(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: 'Тактика',
                  active: false,
                  onTap: onOpenTactics,
                ),
                _navButton(
                  icon: Icons.layers_outlined,
                  label: 'Слои',
                  active: false,
                  onTap: onOpenLayers,
                ),
                _navButton(
                  icon: Icons.tune_rounded,
                  label: 'Свойства',
                  active: state.selected != null,
                  onTap: state.selected == null ? null : onOpenProperties,
                ),
                _navButton(
                  icon: Icons.crop_free_rounded,
                  label: 'Зона',
                  active: state.tool == TgTool.rect || state.tool == TgTool.circle,
                  onTap: () => state.setTool(TgTool.rect),
                ),
                _navButton(
                  icon: Icons.grid_4x4_rounded,
                  label: 'Сетка',
                  active: state.gridEnabled,
                  onTap: state.toggleGrid,
                ),
                _navButton(
                  icon: Icons.text_fields_rounded,
                  label: 'Текст',
                  active: state.tool == TgTool.text,
                  onTap: () => state.setTool(TgTool.text),
                ),
                _navButton(
                  icon: Icons.route_rounded,
                  label: 'Серия',
                  active: state.continuousDrawMode,
                  onTap: state.toggleContinuousDrawMode,
                ),
                const Spacer(),
                _smallActionRow(
                  leftIcon: Icons.undo_rounded,
                  rightIcon: Icons.redo_rounded,
                  onLeft: state.canUndo ? state.undo : null,
                  onRight: state.canRedo ? state.redo : null,
                ),
                const SizedBox(height: 6),
                _zoomBox(),
                const SizedBox(height: 8),
                _bottomIcon(
                  icon: state.lockViewportGestures ? Icons.lock_rounded : Icons.lock_open_rounded,
                  onTap: () => state.setLockViewport(!state.lockViewportGestures),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _brandMark() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _green.withOpacity(.18)),
      ),
      child: const Icon(Icons.sports_soccer_rounded, size: 19, color: _green),
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
    bool showDot = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: active ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: active ? Border.all(color: _green.withOpacity(.20)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: active ? _green : _text),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? _green : _muted,
                        fontFamily: _font,
                        fontSize: 7.6,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (active && showDot)
            Positioned(
              right: -3,
              top: 20,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _smallActionRow({
    required IconData leftIcon,
    required IconData rightIcon,
    required VoidCallback? onLeft,
    required VoidCallback? onRight,
  }) {
    return Container(
      width: 46,
      height: 28,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(child: _miniIcon(leftIcon, onLeft)),
          Container(width: 1, height: 18, color: _border),
          Expanded(child: _miniIcon(rightIcon, onRight)),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Icon(icon, size: 15, color: onTap == null ? _muted.withOpacity(.35) : _text),
    );
  }

  Widget _zoomBox() {
    return Container(
      width: 46,
      height: 28,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(onTap: onResetView, child: const Padding(padding: EdgeInsets.all(4), child: Text('−', style: TextStyle(fontWeight: FontWeight.w900, color: _text)))),
          const Text('100%', style: TextStyle(fontSize: 8.0, color: _text, fontWeight: FontWeight.w800)),
          InkWell(onTap: onZoomToSelection, child: const Padding(padding: EdgeInsets.all(4), child: Text('+', style: TextStyle(fontWeight: FontWeight.w900, color: _text)))),
        ],
      ),
    );
  }

  Widget _bottomIcon({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(icon, color: _text, size: 16),
        ),
      ),
    );
  }
}
