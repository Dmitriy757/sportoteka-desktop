// lib/presentation/training_graphics/widgets/tg_top_toolbar.dart
import 'package:flutter/material.dart';
import '../training_graphics_state.dart';
import '../tg_models.dart';

/// ================== iPad WHITE MINIMAL PALETTE ==================
class TgEditorPaletteW {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF8FAFC); // very light
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF1F5F9);

  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);

  // Sportoteka green
  static const accent = Color(0xFF00A750);
  static const accentSoft = Color(0x1A00A750);

  static const shadow = Color(0x14000000);
}

/// ================== WHITE MINIMAL COMPONENTS ==================
class TgWButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool selected;
  final EdgeInsets padding;
  final double radius;

  const TgWButton({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(10),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TgEditorPaletteW.accentSoft : TgEditorPaletteW.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? TgEditorPaletteW.accent : TgEditorPaletteW.border,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class TgWChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const TgWChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TgWButton(
      selected: selected,
      onTap: onTap,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? TgEditorPaletteW.accent : TgEditorPaletteW.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? TgEditorPaletteW.text : TgEditorPaletteW.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class TgWSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double width;
  final ValueChanged<double> onChanged;
  final String? label;

  const TgWSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.width,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max);
    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: TgEditorPaletteW.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TgEditorPaletteW.border),
      ),
      child: Row(
        children: [
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: const TextStyle(
                color: TgEditorPaletteW.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: TgEditorPaletteW.accent,
                inactiveTrackColor: TgEditorPaletteW.textMuted.withOpacity(0.25),
                thumbColor: TgEditorPaletteW.text,
              ),
              child: Slider(
                value: v,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TgWColorPicker extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;
  final bool showTransparency;
  final List<Color> colors;

  const TgWColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
    this.showTransparency = false,
    this.colors = const [
      Color(0xFF111827),
      Color(0xFF2E2E2E),
      Color(0xFFFFFFFF),
      Color(0xFF00A750),
      Color(0xFF2563EB),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dot(currentColor, active: true),
        ...colors.map((c) => _opt(c)),
        if (showTransparency) _opt(Colors.transparent),
      ],
    );
  }

  Widget _opt(Color c) {
    final active = _same(c, currentColor);
    final isTransparent = c.opacity == 0;

    return InkWell(
      onTap: () => onColorSelected(c),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isTransparent ? Colors.transparent : c,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? TgEditorPaletteW.text : TgEditorPaletteW.border,
            width: active ? 2 : 1.5,
          ),
        ),
        child: isTransparent
            ? Icon(
                Icons.close_rounded,
                size: 14,
                color: TgEditorPaletteW.textMuted.withOpacity(0.9),
              )
            : null,
      ),
    );
  }

  Widget _dot(Color c, {required bool active}) {
    final isTransparent = c.opacity == 0;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isTransparent ? Colors.transparent : c,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? TgEditorPaletteW.accent : TgEditorPaletteW.border,
          width: 2,
        ),
      ),
      child: isTransparent
          ? Icon(
              Icons.close_rounded,
              size: 14,
              color: TgEditorPaletteW.textMuted.withOpacity(0.9),
            )
          : null,
    );
  }

  bool _same(Color a, Color b) => a.value == b.value && a.opacity == b.opacity;
}

class TgWPopup<T> extends StatelessWidget {
  final T value;
  final List<PopupMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget child;

  const TgWPopup({
    super.key,
    required this.value,
    required this.items,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      itemBuilder: (_) => items,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: TgEditorPaletteW.bg,
      elevation: 10,
      child: child,
    );
  }
}

/// ================== TG TOP TOOLBAR (WHITE MINIMAL) ==================
class TgTopToolbar extends StatefulWidget {
  const TgTopToolbar({super.key, required this.state});
  final TgState state;

  @override
  State<TgTopToolbar> createState() => _TgTopToolbarState();
}

class _TgTopToolbarState extends State<TgTopToolbar> with SingleTickerProviderStateMixin {
  TgState get state => widget.state;

  int _selectedTabIndex = 0;

  late final AnimationController _anim;
  late final Animation<double> _fade;

  final ScrollController _toolsScroll = ScrollController();
  final ScrollController _tabsScroll = ScrollController();
  final ScrollController _panelVScroll = ScrollController();

  TgElement? _lastSelected;
  TgTool? _lastTool;
  bool _lastCollapsed = false;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChange);

    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);

    _lastSelected = state.selected;
    _lastTool = state.tool;
    _lastCollapsed = state.topEditorCollapsed;
  }

  @override
  void dispose() {
    state.removeListener(_onStateChange);
    _anim.dispose();
    _toolsScroll.dispose();
    _tabsScroll.dispose();
    _panelVScroll.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;

    if (state.selected == null && _selectedTabIndex != 0) {
      setState(() => _selectedTabIndex = 0);
      _lastSelected = null;
      return;
    }

    final selectedChanged = !identical(_lastSelected, state.selected);
    final toolChanged = _lastTool != state.tool;
    final collapsedChanged = _lastCollapsed != state.topEditorCollapsed;

    if (selectedChanged || toolChanged || collapsedChanged) {
      _lastSelected = state.selected;
      _lastTool = state.tool;
      _lastCollapsed = state.topEditorCollapsed;
      _anim.forward(from: 0);
      setState(() {});
    }
  }

  void _collapseAll() {
    if (!state.topEditorCollapsed) {
      state.toggleTopEditor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedElement = state.selected;
    final collapsed = state.topEditorCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: collapsed ? 44 : 148,
      decoration: const BoxDecoration(
        color: TgEditorPaletteW.bg,
        border: Border(bottom: BorderSide(color: TgEditorPaletteW.border, width: 1)),
      ),
      child: Column(
        children: [
          // TOP ROW
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: TgEditorPaletteW.divider, width: 1)),
            ),
            child: Row(
              children: [
                TgWButton(
                  onTap: state.toggleTopEditor,
                  padding: const EdgeInsets.all(8),
                  radius: 12,
                  child: Icon(
                    collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    color: TgEditorPaletteW.textMuted,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 8),
                TgWButton(
                  onTap: _collapseAll,
                  padding: const EdgeInsets.all(8),
                  radius: 12,
                  child: const Icon(
                    Icons.close_rounded,
                    color: TgEditorPaletteW.textMuted,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: SingleChildScrollView(
                    controller: _toolsScroll,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _tool(Icons.near_me_rounded, "Выбор", TgTool.select),
                        _tool(Icons.show_chart_rounded, "Линия", TgTool.line),
                        _tool(Icons.crop_square_rounded, "Прямоугольник", TgTool.rect),
                        _tool(Icons.circle_outlined, "Круг", TgTool.circle),
                        _tool(Icons.text_fields_rounded, "Текст", TgTool.text),
                        _tool(Icons.category_outlined, "Объект", TgTool.stamp),
                      ],
                    ),
                  ),
                ),

                if (!collapsed && selectedElement != null) ...[
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: TgEditorPaletteW.border,
                  ),
                  _action(Icons.copy_rounded, "Дублировать", state.duplicateSelected),
                  _action(Icons.delete_outline_rounded, "Удалить", state.deleteSelected),
                  _action(Icons.vertical_align_top_rounded, "Вперёд", state.bringToFront),
                  _action(Icons.vertical_align_bottom_rounded, "Назад", state.sendToBack),
                ],
              ],
            ),
          ),

          if (collapsed)
            const SizedBox.shrink()
          else
            Expanded(
              child: AnimatedBuilder(
                animation: _fade,
                builder: (context, child) => FadeTransition(opacity: _fade, child: child),
                child: selectedElement == null ? _empty() : _panel(selectedElement),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TgEditorPaletteW.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TgEditorPaletteW.border),
            ),
            child: const Icon(Icons.info_outline, color: TgEditorPaletteW.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Выберите объект на поле или создайте новый, чтобы настроить параметры",
              style: TextStyle(
                color: TgEditorPaletteW.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(TgElement element) {
    final tabs = _getTabItems(element);
    if (_selectedTabIndex >= tabs.length) _selectedTabIndex = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            controller: _tabsScroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(tabs.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TgWChip(
                    label: tabs[i].label,
                    icon: tabs[i].icon,
                    selected: i == _selectedTabIndex,
                    onTap: () => setState(() => _selectedTabIndex = i),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: TgEditorPaletteW.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TgEditorPaletteW.border),
              ),
              child: Scrollbar(
                controller: _panelVScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _panelVScroll,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: _buildTabContent(element),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, TgTool tool) {
    final selected = state.tool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: TgWButton(
          selected: selected,
          onTap: () => state.setTool(tool),
          padding: const EdgeInsets.all(9),
          radius: 12,
          child: Icon(
            icon,
            size: 20,
            color: selected ? TgEditorPaletteW.accent : TgEditorPaletteW.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: TgWButton(
          onTap: onTap,
          padding: const EdgeInsets.all(9),
          radius: 12,
          child: Icon(icon, size: 20, color: TgEditorPaletteW.textMuted),
        ),
      ),
    );
  }

  // ================== CONTENT ==================

  List<_TabItem> _getTabItems(TgElement element) {
    if (element is TgLine) {
      return const [
        _TabItem("Стиль", Icons.palette_outlined),
        _TabItem("Геометрия", Icons.straighten_rounded),
        _TabItem("Трансформация", Icons.transform_rounded),
        _TabItem("Стрелка", Icons.arrow_forward_rounded),
      ];
    }
    if (element is TgText) {
      return const [
        _TabItem("Стиль", Icons.palette_outlined),
        _TabItem("Текст", Icons.text_fields_rounded),
        _TabItem("Трансформация", Icons.transform_rounded),
      ];
    }
    if (element is TgStamp) {
      return const [
        _TabItem("Стиль", Icons.palette_outlined),
        _TabItem("Параметры", Icons.category_outlined),
        _TabItem("Трансформация", Icons.transform_rounded),
      ];
    }
    return const [
      _TabItem("Стиль", Icons.palette_outlined),
      _TabItem("Геометрия", Icons.straighten_rounded),
      _TabItem("Трансформация", Icons.transform_rounded),
    ];
  }

  Widget _buildTabContent(TgElement element) {
    if (element is TgLine) {
      if (_selectedTabIndex == 0) return _buildLineStyle(element);
      if (_selectedTabIndex == 1) return _buildLineGeometry(element);
      if (_selectedTabIndex == 2) return _buildTransformControls();
      return _buildLineArrow(element);
    }

    if (element is TgRect) {
      if (_selectedTabIndex == 0) return _buildRectStyle(element);
      if (_selectedTabIndex == 1) return _buildRectGeometry(element);
      return _buildTransformControls();
    }

    if (element is TgCircle) {
      if (_selectedTabIndex == 0) return _buildCircleStyle(element);
      if (_selectedTabIndex == 1) return _buildCircleGeometry(element);
      return _buildTransformControls();
    }

    if (element is TgText) {
      if (_selectedTabIndex == 0) return _buildTextStyle(element);
      if (_selectedTabIndex == 1) return _buildTextContent(element);
      return _buildTransformControls();
    }

    if (element is TgStamp) {
      if (_selectedTabIndex == 0) return _buildStampStyle(element);
      if (_selectedTabIndex == 1) return _buildStampProperties(element);
      return _buildTransformControls();
    }

    return const SizedBox.shrink();
  }

  // ---------- UI helpers ----------
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          t,
          style: const TextStyle(
            color: TgEditorPaletteW.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _popupBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TgEditorPaletteW.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TgEditorPaletteW.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: TgEditorPaletteW.text,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18, color: TgEditorPaletteW.textMuted),
        ],
      ),
    );
  }

  // ================== BUILDERS ==================

  Widget _buildLineStyle(TgLine line) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Цвет"),
        TgWColorPicker(
          currentColor: line.color,
          onColorSelected: (c) => state.updateSelectedLine(color: c),
        ),
        const SizedBox(width: 4),
        _label("Тип"),
        TgWPopup<LineKind>(
          value: line.kind,
          items: const [
            PopupMenuItem(value: LineKind.normal, child: Text("Сплошная")),
            PopupMenuItem(value: LineKind.dashed, child: Text("Пунктир")),
            PopupMenuItem(value: LineKind.dotted, child: Text("Точечная")),
          ],
          onSelected: (k) => state.updateSelectedLine(kind: k),
          child: _popupBox(_lineKindName(line.kind)),
        ),
      ],
    );
  }

  Widget _buildLineGeometry(TgLine line) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Толщина"),
        TgWSlider(
          value: line.width,
          min: 1,
          max: 26,
          width: 180,
          onChanged: (v) => state.updateSelectedLine(width: v),
          label: "${line.width.toInt()}px",
        ),
      ],
    );
  }

  Widget _buildLineArrow(TgLine line) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Окончание"),
        TgWPopup<LineEnd>(
          value: line.end,
          items: const [
            PopupMenuItem(value: LineEnd.none, child: Text("Нет")),
            PopupMenuItem(value: LineEnd.arrow, child: Text("Стрелка")),
            PopupMenuItem(value: LineEnd.diamond, child: Text("Ромб")),
            PopupMenuItem(value: LineEnd.circle, child: Text("Круг")),
          ],
          onSelected: (e) => state.updateSelectedLine(end: e),
          child: _popupBox(_lineEndName(line.end)),
        ),
        _label("Размер"),
        TgWSlider(
          value: line.arrowSize,
          min: 0,
          max: 34,
          width: 200,
          onChanged: (v) => state.updateSelectedLine(arrow: v),
          label: "${line.arrowSize.toInt()}px",
        ),
      ],
    );
  }

  Widget _buildRectStyle(TgRect rect) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Заливка"),
        TgWColorPicker(
          currentColor: rect.fill.withOpacity(rect.opacity),
          onColorSelected: (c) => state.updateSelectedShape(fill: c, opacity: c.opacity),
          showTransparency: true,
        ),
        _label("Прозрачность"),
        TgWSlider(
          value: rect.opacity * 100,
          min: 0,
          max: 100,
          width: 210,
          onChanged: (v) => state.updateSelectedShape(opacity: v / 100),
          label: "${(rect.opacity * 100).toInt()}%",
        ),
        _label("Обводка"),
        TgWColorPicker(
          currentColor: rect.border,
          onColorSelected: (c) => state.updateSelectedShape(border: c),
          showTransparency: true,
        ),
        TgWSlider(
          value: rect.borderWidth,
          min: 0,
          max: 20,
          width: 190,
          onChanged: (v) => state.updateSelectedShape(borderW: v),
          label: "${rect.borderWidth.toInt()}px",
        ),
        TgWPopup<BorderKind>(
          value: rect.borderKind,
          items: const [
            PopupMenuItem(value: BorderKind.solid, child: Text("Сплошная")),
            PopupMenuItem(value: BorderKind.dashed, child: Text("Пунктир")),
            PopupMenuItem(value: BorderKind.dotted, child: Text("Точечная")),
            PopupMenuItem(value: BorderKind.doubleLine, child: Text("Двойная")),
          ],
          onSelected: (k) => state.updateSelectedShape(kind: k),
          child: _popupBox(_borderKindName(rect.borderKind)),
        ),
      ],
    );
  }

  Widget _buildRectGeometry(TgRect rect) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Радиус"),
        TgWSlider(
          value: rect.borderRadius,
          min: 0,
          max: 80,
          width: 240,
          onChanged: (v) => state.updateSelectedShape(borderRadius: v),
          label: "${rect.borderRadius.toInt()}px",
        ),
      ],
    );
  }

  Widget _buildCircleStyle(TgCircle circle) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Заливка"),
        TgWColorPicker(
          currentColor: circle.fill.withOpacity(circle.opacity),
          onColorSelected: (c) => state.updateSelectedShape(fill: c, opacity: c.opacity),
          showTransparency: true,
        ),
        _label("Прозрачность"),
        TgWSlider(
          value: circle.opacity * 100,
          min: 0,
          max: 100,
          width: 210,
          onChanged: (v) => state.updateSelectedShape(opacity: v / 100),
          label: "${(circle.opacity * 100).toInt()}%",
        ),
        _label("Обводка"),
        TgWColorPicker(
          currentColor: circle.border,
          onColorSelected: (c) => state.updateSelectedShape(border: c),
          showTransparency: true,
        ),
        TgWSlider(
          value: circle.borderWidth,
          min: 0,
          max: 20,
          width: 190,
          onChanged: (v) => state.updateSelectedShape(borderW: v),
          label: "${circle.borderWidth.toInt()}px",
        ),
        TgWPopup<BorderKind>(
          value: circle.borderKind,
          items: const [
            PopupMenuItem(value: BorderKind.solid, child: Text("Сплошная")),
            PopupMenuItem(value: BorderKind.dashed, child: Text("Пунктир")),
            PopupMenuItem(value: BorderKind.dotted, child: Text("Точечная")),
            PopupMenuItem(value: BorderKind.doubleLine, child: Text("Двойная")),
          ],
          onSelected: (k) => state.updateSelectedShape(kind: k),
          child: _popupBox(_borderKindName(circle.borderKind)),
        ),
      ],
    );
  }

  Widget _buildCircleGeometry(TgCircle circle) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Радиус"),
        TgWSlider(
          value: circle.radius,
          min: 10,
          max: 340,
          width: 260,
          onChanged: (v) => state.updateSelectedShape(radius: v),
          label: "${circle.radius.toInt()}px",
        ),
      ],
    );
  }

  Widget _buildTextStyle(TgText text) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Цвет"),
        TgWColorPicker(
          currentColor: text.color,
          onColorSelected: (c) => state.updateSelectedText(color: c),
        ),
        _label("Размер"),
        TgWSlider(
          value: text.size,
          min: 8,
          max: 140,
          width: 240,
          onChanged: (v) => state.updateSelectedText(size: v),
          label: "${text.size.toInt()}px",
        ),
      ],
    );
  }

  Widget _buildTextContent(TgText text) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Стиль"),
        _toggle(Icons.format_bold_rounded, "Bold", text.weight == FontWeight.w900, () {
          final w = text.weight == FontWeight.w900 ? FontWeight.w500 : FontWeight.w900;
          state.updateSelectedText(weight: w);
        }),
        _toggle(Icons.format_italic_rounded, "Italic", text.style == TgTextStyle.italic, () {
          final s = text.style == TgTextStyle.italic ? TgTextStyle.normal : TgTextStyle.italic;
          state.updateSelectedText(style: s);
        }),
        _toggle(Icons.format_underline_rounded, "Underline", text.style == TgTextStyle.underline, () {
          final s = text.style == TgTextStyle.underline ? TgTextStyle.normal : TgTextStyle.underline;
          state.updateSelectedText(style: s);
        }),
      ],
    );
  }

  Widget _buildStampStyle(TgStamp stamp) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Прозрачность"),
        TgWSlider(
          value: stamp.opacity * 100,
          min: 0,
          max: 100,
          width: 260,
          onChanged: (v) => state.setSelectedStampOpacity(v / 100),
          label: "${(stamp.opacity * 100).toInt()}%",
        ),
      ],
    );
  }

  Widget _buildStampProperties(TgStamp stamp) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label("Размер"),
        TgWSlider(
          value: stamp.size.toDouble(),
          min: 18,
          max: 260,
          width: 280,
          onChanged: (v) => state.setSelectedStampSize(v),
          label: "${stamp.size}px",
        ),
      ],
    );
  }

  Widget _buildTransformControls() {
    final snapVal = state.snapRotationEnabled ? state.snapRotationDegrees.round() : 0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _action(Icons.rotate_left, "Повернуть -15°", () => _rotateBy(-15)),
        _action(Icons.rotate_right, "Повернуть +15°", () => _rotateBy(15)),

        TgWButton(
          onTap: () {},
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          radius: 12,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: snapVal,
              dropdownColor: TgEditorPaletteW.bg,
              style: const TextStyle(
                color: TgEditorPaletteW.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: TgEditorPaletteW.textMuted),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Snap OFF")),
                DropdownMenuItem(value: 5, child: Text("5°")),
                DropdownMenuItem(value: 15, child: Text("15°")),
                DropdownMenuItem(value: 30, child: Text("30°")),
                DropdownMenuItem(value: 45, child: Text("45°")),
              ],
              onChanged: (v) {
                if (v == null) return;
                state.setSnapRotation(enabled: v > 0, degrees: v.toDouble());
              },
            ),
          ),
        ),

        _action(Icons.zoom_out, "Уменьшить", () => _scaleBy(0.9)),
        _action(Icons.zoom_in, "Увеличить", () => _scaleBy(1.1)),
        _action(Icons.refresh, "Сбросить поворот", () => state.setSelectedRotationAbsolute(0.0)),
      ],
    );
  }

  Widget _toggle(IconData icon, String label, bool selected, VoidCallback onTap) {
    return TgWButton(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? TgEditorPaletteW.accent : TgEditorPaletteW.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? TgEditorPaletteW.text : TgEditorPaletteW.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ================== ACTIONS ==================
  void _rotateBy(double degrees) {
    final radians = degrees * 3.141592653589793 / 180.0;
    state.rotateSelected(radians);
  }

  void _scaleBy(double factor) {
    // ✅ РЕАЛЬНО масштабируем выбранный элемент
    state.scaleSelectedBy(factor);
  }

  // ================== NAMES ==================
  String _lineKindName(LineKind kind) {
    switch (kind) {
      case LineKind.normal:
        return "Сплошная";
      case LineKind.dashed:
        return "Пунктир";
      case LineKind.dotted:
        return "Точечная";
    }
  }

  String _lineEndName(LineEnd end) {
    switch (end) {
      case LineEnd.none:
        return "Нет";
      case LineEnd.arrow:
        return "Стрелка";
      case LineEnd.diamond:
        return "Ромб";
      case LineEnd.circle:
        return "Круг";
    }
  }

  String _borderKindName(BorderKind kind) {
    switch (kind) {
      case BorderKind.solid:
        return "Сплошная";
      case BorderKind.dashed:
        return "Пунктир";
      case BorderKind.dotted:
        return "Точечная";
      case BorderKind.doubleLine:
        return "Двойная";
    }
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon);
  final String label;
  final IconData icon;
}