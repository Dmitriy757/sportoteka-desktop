import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';

/// Оверлей-кнопки поверх TgCanvas:
/// - инструменты
/// - undo/redo
/// - zoom controls
/// - grid toggle
/// - lock viewport
/// - fit/reset/zoom-to-selection через TgCanvasStateProxy
class TgCanvasOverlayControls extends StatelessWidget {
  const TgCanvasOverlayControls({
    super.key,
    required this.state,
    required this.canvasProxy,
  });

  final TgState state;

  /// Передай сюда GlobalKey<TgCanvasState> (который implements TgCanvasStateProxy)
  final TgCanvasStateProxy? canvasProxy;

  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return IgnorePointer(
          ignoring: false,
          child: Stack(
            children: [
              // ===== LEFT TOOL BAR =====
              Positioned(
                left: 12,
                top: 12,
                bottom: 12,
                child: _LeftRail(
                  state: state,
                  onResetView: () => canvasProxy?.resetView(),
                  onZoomToSelection: () => canvasProxy?.zoomToSelection(),
                ),
              ),

              // ===== RIGHT VIEW BAR =====
              Positioned(
                right: 12,
                top: 12,
                child: _RightTopBar(
                  state: state,
                  onResetView: () => canvasProxy?.resetView(),
                  onFit: () {
                    // resetView у тебя и есть fitFieldToViewport(последний viewport)
                    canvasProxy?.resetView();
                  },
                ),
              ),

              // ===== BOTTOM ZOOM =====
              Positioned(
                right: 12,
                bottom: 12,
                child: _BottomZoomBar(
                  state: state,
                  onZoomIn: () {
                    // зум “через трансформ”: чуть приблизим сцену
                    _nudgeViewportScale(state, factor: 1.12);
                  },
                  onZoomOut: () {
                    _nudgeViewportScale(state, factor: 0.88);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Лёгкий zoom без доступа к приватным _scale/_t:
  /// Мы масштабируем текущую Matrix4 вокруг центра экрана (примерно).
  static void _nudgeViewportScale(TgState state, {required double factor}) {
    final m = state.transform.value.value.clone();

    // текущий scale (примерно)
    final currentScale = m.storage[0].abs().clamp(0.2, 4.0);
    final next = (currentScale * factor).clamp(0.20, 4.0);

    // коэффициент на матрицу (чтобы не было прыжка)
    final k = (next / currentScale).clamp(0.5, 2.0);

    // scale from origin (это ок, т.к. TgCanvas уже clamp-ит при панорамировании
    // + есть resetView/zoomToSelection)
    m.scale(k, k);

    state.transform.value.value = m;
    state.notifyListeners();
  }
}

// =====================================================
// LEFT RAIL (инструменты + undo/redo + selection ops)
// =====================================================
class _LeftRail extends StatelessWidget {
  const _LeftRail({
    required this.state,
    required this.onResetView,
    required this.onZoomToSelection,
  });

  final TgState state;
  final VoidCallback onResetView;
  final VoidCallback onZoomToSelection;

  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    final hasSel = state.selected != null;

    return Container(
      width: 54,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          _ToolBtn(
            icon: Icons.near_me_rounded,
            active: state.tool == TgTool.select,
            tip: "Выбор",
            onTap: () => state.setTool(TgTool.select),
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.show_chart_rounded,
            active: state.tool == TgTool.line,
            tip: "Линия",
            onTap: () => state.setTool(TgTool.line),
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.crop_square_rounded,
            active: state.tool == TgTool.rect,
            tip: "Прямоугольник",
            onTap: () => state.setTool(TgTool.rect),
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.circle_outlined,
            active: state.tool == TgTool.circle,
            tip: "Круг",
            onTap: () => state.setTool(TgTool.circle),
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.text_fields_rounded,
            active: state.tool == TgTool.text,
            tip: "Текст",
            onTap: () => state.setTool(TgTool.text),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 12),

          _ToolBtn(
            icon: Icons.undo_rounded,
            active: false,
            tip: "Undo",
            enabled: state.canUndo,
            onTap: state.canUndo ? state.undo : null,
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.redo_rounded,
            active: false,
            tip: "Redo",
            enabled: state.canRedo,
            onTap: state.canRedo ? state.redo : null,
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 12),

          _ToolBtn(
            icon: Icons.grid_on_rounded,
            active: state.gridEnabled,
            tip: "Сетка",
            onTap: state.toggleGrid,
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: state.lockViewportGestures ? Icons.lock_rounded : Icons.lock_open_rounded,
            active: state.lockViewportGestures,
            tip: state.lockViewportGestures ? "Разблок." : "Блокировка",
            onTap: () => state.setLockViewport(!state.lockViewportGestures),
          ),

          const Spacer(),

          _ToolBtn(
            icon: Icons.center_focus_strong_rounded,
            active: false,
            tip: "К выделению",
            enabled: hasSel,
            onTap: hasSel ? onZoomToSelection : null,
          ),
          const SizedBox(height: 8),
          _ToolBtn(
            icon: Icons.refresh_rounded,
            active: false,
            tip: "Сброс вида",
            onTap: onResetView,
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.active,
    required this.tip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final bool active;
  final String tip;
  final VoidCallback? onTap;
  final bool enabled;

  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    final bg = active ? _green.withOpacity(0.22) : Colors.white.withOpacity(0.08);
    final br = active ? _green.withOpacity(0.55) : Colors.white.withOpacity(0.12);
    final ic = active ? _green : Colors.white.withOpacity(enabled ? 0.92 : 0.35);

    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: enabled ? bg : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: br),
          ),
          child: Icon(icon, color: ic, size: 22),
        ),
      ),
    );
  }
}

// =====================================================
// RIGHT TOP BAR (быстрые команды вида)
// =====================================================
class _RightTopBar extends StatelessWidget {
  const _RightTopBar({
    required this.state,
    required this.onResetView,
    required this.onFit,
  });

  final TgState state;
  final VoidCallback onResetView;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBtn(
            icon: Icons.fit_screen_rounded,
            tip: "Fit",
            onTap: onFit,
          ),
          const SizedBox(width: 8),
          _MiniBtn(
            icon: Icons.refresh_rounded,
            tip: "Reset",
            onTap: onResetView,
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.tip,
    required this.onTap,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.92), size: 22),
        ),
      ),
    );
  }
}

// =====================================================
// BOTTOM ZOOM BAR
// =====================================================
class _BottomZoomBar extends StatelessWidget {
  const _BottomZoomBar({
    required this.state,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final TgState state;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBtn(icon: Icons.add_rounded, tip: "Zoom +", onTap: onZoomIn),
          const SizedBox(height: 8),
          _MiniBtn(icon: Icons.remove_rounded, tip: "Zoom −", onTap: onZoomOut),
        ],
      ),
    );
  }
}