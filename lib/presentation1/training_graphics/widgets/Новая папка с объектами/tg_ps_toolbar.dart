import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

/// Photoshop-like left toolbar (dock) with flyout submenus.
class TgPsToolbar extends StatefulWidget {
  const TgPsToolbar({
    super.key,
    required this.state,
    this.width = 52,
    this.onToolChanged,
  });

  final TgState state;
  final double width;
  final VoidCallback? onToolChanged;

  @override
  State<TgPsToolbar> createState() => _TgPsToolbarState();
}

class _TgPsToolbarState extends State<TgPsToolbar> {
  TgState get state => widget.state;

  // which button has flyout opened
  _FlyoutKey? _openFlyout;

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
  }

  void _onState() {
    if (!mounted) return;
    setState(() {}); // reflect tool changes, etc.
  }

  @override
  void dispose() {
    state.removeListener(_onState);
    super.dispose();
  }

  void _toggleFlyout(_FlyoutKey key) {
    setState(() {
      _openFlyout = (_openFlyout == key) ? null : key;
    });
  }

  void _closeFlyout() {
    if (_openFlyout != null) {
      setState(() => _openFlyout = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeFlyout,
      child: SizedBox(
        width: w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dock itself
            _Dock(
              width: w,
              children: [
                // SELECT group (select / marquee)
                _ToolBtn(
                  icon: Icons.open_with_rounded,
                  active: state.tool == TgTool.select,
                  hasFlyout: true,
                  onTap: () => _toggleFlyout(_FlyoutKey.selectGroup),
                  onDoubleTap: () {
                    state.setTool(TgTool.select);
                    widget.onToolChanged?.call();
                  },
                ),
                const SizedBox(height: 6),

                // LINE group
                _ToolBtn(
                  icon: Icons.show_chart_rounded,
                  active: state.tool == TgTool.line,
                  hasFlyout: true,
                  onTap: () => _toggleFlyout(_FlyoutKey.lineGroup),
                  onDoubleTap: () {
                    state.setTool(TgTool.line);
                    widget.onToolChanged?.call();
                  },
                ),
                const SizedBox(height: 6),

                // TEXT
                _ToolBtn(
                  icon: Icons.text_fields_rounded,
                  active: state.tool == TgTool.text,
                  onTap: () {
                    _closeFlyout();
                    state.setTool(TgTool.text);
                    widget.onToolChanged?.call();
                  },
                ),
                const SizedBox(height: 6),

                // SHAPES group (rect/circle)
                _ToolBtn(
                  icon: Icons.crop_square_rounded,
                  active: state.tool == TgTool.rect || state.tool == TgTool.circle,
                  hasFlyout: true,
                  onTap: () => _toggleFlyout(_FlyoutKey.shapeGroup),
                  onDoubleTap: () {
                    state.setTool(TgTool.rect);
                    widget.onToolChanged?.call();
                  },
                ),
                const SizedBox(height: 6),

                // STAMP / props picker
                _ToolBtn(
                  icon: Icons.sports_soccer_rounded,
                  active: state.tool == TgTool.stamp,
                  onTap: () {
                    _closeFlyout();
                    state.setTool(TgTool.stamp);
                    widget.onToolChanged?.call();
                  },
                ),

                const Spacer(),

                // small bottom actions like PS
                _ToolBtn(
                  icon: Icons.undo_rounded,
                  active: false,
                  onTap: state.canUndo ? state.undo : null,
                ),
                const SizedBox(height: 6),
                _ToolBtn(
                  icon: Icons.redo_rounded,
                  active: false,
                  onTap: state.canRedo ? state.redo : null,
                ),
              ],
            ),

            // Flyouts (appear to the right of dock)
            if (_openFlyout == _FlyoutKey.selectGroup)
              _Flyout(
                left: w + 8,
                top: 6,
                title: "Выделение",
                items: [
                  _FlyoutItem(
                    icon: Icons.open_with_rounded,
                    title: "Выделение / перемещение",
                    subtitle: "Перемещение, масштаб, поворот",
                    active: state.tool == TgTool.select,
                    onTap: () {
                      state.setTool(TgTool.select);
                      widget.onToolChanged?.call();
                      _closeFlyout();
                    },
                  ),
                  _FlyoutItem(
                    icon: Icons.select_all_rounded,
                    title: "Рамка (marquee)",
                    subtitle: "Мультивыделение рамкой",
                    active: false, // если у тебя есть отдельный режим — привяжи
                    onTap: () {
                      // если нет отдельного tool — можно включать "маркировку" флагом в state
                      // state.setMarqueeMode(true);
                      _closeFlyout();
                    },
                  ),
                ],
              ),

            if (_openFlyout == _FlyoutKey.lineGroup)
              _Flyout(
                left: w + 8,
                top: 64,
                title: "Линии",
                items: [
                  _FlyoutItem(
                    icon: Icons.show_chart_rounded,
                    title: "Линия",
                    subtitle: "Прямая/кривая/стрелки",
                    active: state.tool == TgTool.line,
                    onTap: () {
                      state.setTool(TgTool.line);
                      widget.onToolChanged?.call();
                      _closeFlyout();
                    },
                  ),
                  _FlyoutItem(
                    icon: Icons.waves_rounded,
                    title: "Волна",
                    subtitle: "Волнистая траектория",
                    active: false,
                    onTap: () {
                      state.setTool(TgTool.line);
                      // дальше тип (wavy) выбирается справа в свойствах
                      _closeFlyout();
                    },
                  ),
                ],
              ),

            if (_openFlyout == _FlyoutKey.shapeGroup)
              _Flyout(
                left: w + 8,
                top: 172,
                title: "Фигуры",
                items: [
                  _FlyoutItem(
                    icon: Icons.crop_square_rounded,
                    title: "Прямоугольник",
                    subtitle: "Рамка/пунктир/толщина",
                    active: state.tool == TgTool.rect,
                    onTap: () {
                      state.setTool(TgTool.rect);
                      widget.onToolChanged?.call();
                      _closeFlyout();
                    },
                  ),
                  _FlyoutItem(
                    icon: Icons.circle_outlined,
                    title: "Круг",
                    subtitle: "Рамка/пунктир/толщина",
                    active: state.tool == TgTool.circle,
                    onTap: () {
                      state.setTool(TgTool.circle);
                      widget.onToolChanged?.call();
                      _closeFlyout();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _FlyoutKey { selectGroup, lineGroup, shapeGroup }

class _Dock extends StatelessWidget {
  const _Dock({required this.width, required this.children});
  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.35)),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 10), color: Color(0x33000000)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.active,
    this.hasFlyout = false,
    this.onTap,
    this.onDoubleTap,
  });

  final IconData icon;
  final bool active;
  final bool hasFlyout;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: active ? const Color(0xFF3D3D3D) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: active ? Colors.white : Colors.white.withOpacity(0.82),
                    ),
                  ),
                  if (hasFlyout)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Flyout extends StatelessWidget {
  const _Flyout({
    required this.left,
    required this.top,
    required this.title,
    required this.items,
  });

  final double left;
  final double top;
  final String title;
  final List<_FlyoutItem> items;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.35)),
            boxShadow: const [
              BoxShadow(blurRadius: 22, offset: Offset(0, 12), color: Color(0x4D000000)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final it in items) ...[
                it,
                const SizedBox(height: 8),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _FlyoutItem extends StatelessWidget {
  const _FlyoutItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF3D3D3D) : const Color(0xFF333333),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.92), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
