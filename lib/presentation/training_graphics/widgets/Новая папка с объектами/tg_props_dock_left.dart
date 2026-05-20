// lib/presentation/training_graphics/widgets/tg_props_dock_left.dart
//
// ⚠️ ВАЖНО:
// Этот файл использует TgState.updateElement(id, mutate).
// Если у тебя его ещё нет — добавь в TgState (training_graphics_state.dart):
//
//   void updateElement(String id, TgElement Function(TgElement e) mutate) {
//     if (fieldEditMode) return;
//     final i = elements.indexWhere((e) => e.id == id);
//     if (i == -1) return;
//     _commitHistory();
//     elements[i] = mutate(elements[i]);
//     notifyListeners();
//   }
//
// Также полезно иметь getById, но не обязательно.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../training_graphics_state.dart';
import '../tg_models.dart';

enum ToolSection { select, line, text, shape, stamps, properties, palette, layers, history }

class TgPropsDockLeft extends StatefulWidget {
  final TgState state;
  final bool open;
  final VoidCallback onClose;
  final double width;

  const TgPropsDockLeft({
    super.key,
    required this.state,
    required this.open,
    required this.onClose,
    this.width = 360,
  });

  @override
  State<TgPropsDockLeft> createState() => _TgPropsDockLeftState();
}

class _TgPropsDockLeftState extends State<TgPropsDockLeft> with TickerProviderStateMixin {
  TgState get state => widget.state;

  ToolSection _activeSection = ToolSection.properties;

  final Map<String, bool> _panelExpanded = {
    'transform': true,
    'appearance': true,
    'typography': false,
    'line': true,
    'stamp': true,
    'effects': false,
    'advanced': false,
  };

  final _textController = TextEditingController();
  final _textFieldFocus = FocusNode();
  String? _lastSelectedId;

  late final AnimationController _panelAnimController;
  late final Animation<double> _panelAnim;

  final List<Color> _recentColors = [
    Colors.black,
    const Color(0xFF00A750),
    const Color(0xFF2563EB),
    Colors.red,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChange);

    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _panelAnim = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.open) _panelAnimController.forward();
    _onStateChange();
  }

  @override
  void didUpdateWidget(covariant TgPropsDockLeft oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _panelAnimController.forward();
      } else {
        _panelAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    state.removeListener(_onStateChange);
    _textController.dispose();
    _textFieldFocus.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;

    final selected = state.selected;
    if (selected is TgText) {
      if (_lastSelectedId != selected.id) {
        _lastSelectedId = selected.id;
        _textController.text = selected.text;
      } else if (_textController.text != selected.text) {
        _textController.text = selected.text;
      }
    } else {
      _lastSelectedId = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _panelAnim,
      builder: (context, child) {
       final double targetW = widget.open
    ? (widget.width.clamp(300.0, 520.0) as double)
    : 72.0;

        return Container(
          width: targetW,
          margin: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: _buildDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              _buildToolRail(),
              if (widget.open) _buildVerticalDivider(),
              if (widget.open) _buildMainPanel(),
            ],
          ),
        );
      },
    );
  }

  // ==================== LEFT TOOL RAIL ====================

  Widget _buildToolRail() {
    return Container(
      width: 72,
      color: const Color(0xFF2B2B2B),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildRailIcon(
              icon: widget.open ? Icons.chevron_left : Icons.chevron_right,
              tooltip: widget.open ? 'Свернуть панель' : 'Развернуть панель',
              isActive: false,
              onTap: widget.onClose,
            ),
            const SizedBox(height: 16),
            _buildRailDivider(),
            const SizedBox(height: 16),

            _buildRailIcon(
              icon: Icons.near_me_rounded,
              tooltip: 'Выделение (V)',
              isActive: _activeSection == ToolSection.select,
              onTap: () => setState(() => _activeSection = ToolSection.select),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.timeline_rounded,
              tooltip: 'Линия / Стрелка (L)',
              isActive: _activeSection == ToolSection.line,
              onTap: () => setState(() => _activeSection = ToolSection.line),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.title_rounded,
              tooltip: 'Текст (T)',
              isActive: _activeSection == ToolSection.text,
              onTap: () => setState(() => _activeSection = ToolSection.text),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.crop_square_rounded,
              tooltip: 'Фигуры (U)',
              isActive: _activeSection == ToolSection.shape,
              onTap: () => setState(() => _activeSection = ToolSection.shape),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.sports_soccer_rounded,
              tooltip: 'Объекты / Штампы',
              isActive: _activeSection == ToolSection.stamps,
              onTap: () => setState(() => _activeSection = ToolSection.stamps),
            ),

            const SizedBox(height: 16),
            _buildRailDivider(),
            const SizedBox(height: 16),

            _buildRailIcon(
              icon: Icons.tune_rounded,
              tooltip: 'Свойства',
              isActive: _activeSection == ToolSection.properties,
              onTap: () => setState(() => _activeSection = ToolSection.properties),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.palette_outlined,
              tooltip: 'Палитра',
              isActive: _activeSection == ToolSection.palette,
              onTap: () => setState(() => _activeSection = ToolSection.palette),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.layers_rounded,
              tooltip: 'Слои',
              isActive: _activeSection == ToolSection.layers,
              onTap: () => setState(() => _activeSection = ToolSection.layers),
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.history_rounded,
              tooltip: 'История',
              isActive: _activeSection == ToolSection.history,
              onTap: () => setState(() => _activeSection = ToolSection.history),
            ),

            const Spacer(),

            _buildRailIcon(
              icon: Icons.settings_rounded,
              tooltip: 'Настройки',
              isActive: false,
              onTap: () {},
            ),
            const SizedBox(height: 8),

            _buildRailIcon(
              icon: Icons.help_outline_rounded,
              tooltip: 'Помощь',
              isActive: false,
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRailIcon({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: isActive ? const Color(0xFF3A3A3A) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? Colors.white.withOpacity(0.30) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white.withOpacity(isActive ? 1.0 : 0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailDivider() {
    return Container(
      height: 1,
      width: 40,
      color: Colors.white.withOpacity(0.15),
    );
  }

  // ==================== MAIN PANEL ====================

  Widget _buildMainPanel() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _buildPanelHeader(),
            Expanded(child: _buildPanelContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    final selected = state.selected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getSectionIcon(_activeSection),
              size: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getSectionTitle(_activeSection),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  selected != null ? _getElementTypeName(selected) : 'Ничего не выбрано',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          if (selected != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Дублировать (Ctrl+D)',
              onPressed: state.duplicateSelected,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Удалить (Del)',
              onPressed: state.deleteSelected,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPanelContent() {
    switch (_activeSection) {
      case ToolSection.select:
        return _buildSelectPanel();
      case ToolSection.line:
        return _buildLineToolPanel();
      case ToolSection.text:
        return _buildTextToolPanel();
      case ToolSection.shape:
        return _buildShapeToolPanel();
      case ToolSection.stamps:
        return _buildStampsToolPanel();
      case ToolSection.properties:
        return _buildPropertiesPanelContent();
      case ToolSection.palette:
        return _buildPalettePanel();
      case ToolSection.layers:
        return _buildLayersPanel();
      case ToolSection.history:
        return _buildHistoryPanel();
    }
  }

  // ==================== PROPERTIES ====================

  Widget _buildPropertiesPanelContent() {
    final selected = state.selected;

    if (selected == null) {
      return _buildEmptyState(
        'Выберите объект на холсте',
        'Свойства выбранного объекта появятся здесь',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCollapsiblePanel(
            id: 'transform',
            title: 'Трансформация',
            icon: Icons.transform_rounded,
            child: _buildTransformPanel(selected),
          ),
          const SizedBox(height: 12),

          _buildCollapsiblePanel(
            id: 'appearance',
            title: 'Внешний вид',
            icon: Icons.palette_rounded,
            child: _buildAppearancePanel(selected),
          ),

          if (selected is TgText) ...[
            const SizedBox(height: 12),
            _buildCollapsiblePanel(
              id: 'typography',
              title: 'Текст',
              icon: Icons.format_size_rounded,
              initiallyExpanded: true,
              child: _buildTypographyPanel(selected),
            ),
          ],

          if (selected is TgLine) ...[
            const SizedBox(height: 12),
            _buildCollapsiblePanel(
              id: 'line',
              title: 'Линия',
              icon: Icons.show_chart_rounded,
              initiallyExpanded: true,
              child: _buildLinePropertiesPanel(selected),
            ),
          ],

          if (selected is TgStamp) ...[
            const SizedBox(height: 12),
            _buildCollapsiblePanel(
              id: 'stamp',
              title: 'Штамп',
              icon: Icons.photo_size_select_actual_rounded,
              initiallyExpanded: true,
              child: _buildStampPropertiesPanel(selected),
            ),
          ],

          const SizedBox(height: 12),
          _buildCollapsiblePanel(
            id: 'effects',
            title: 'Эффекты',
            icon: Icons.auto_awesome_rounded,
            initiallyExpanded: false,
            child: _buildEffectsPanel(selected),
          ),

          const SizedBox(height: 12),
          _buildCollapsiblePanel(
            id: 'advanced',
            title: 'Дополнительно',
            icon: Icons.settings_rounded,
            initiallyExpanded: false,
            child: _buildAdvancedPanel(selected),
          ),
        ],
      ),
    );
  }

  Widget _buildTransformPanel(TgElement selected) {
    return Column(
      children: [
        _buildXYControls(selected),
        const SizedBox(height: 14),
        _buildWHControls(selected),
        const SizedBox(height: 14),
        _buildRotationControls(selected),
        const SizedBox(height: 14),
        _buildTransformButtons(),
      ],
    );
  }

  Widget _buildXYControls(TgElement selected) {
    return Row(
      children: [
        Expanded(
          child: _buildNumberField(
            label: 'X',
            value: _getX(selected).round(),
            onSubmit: (v) => _setXY(selected, x: v.toDouble()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildNumberField(
            label: 'Y',
            value: _getY(selected).round(),
            onSubmit: (v) => _setXY(selected, y: v.toDouble()),
          ),
        ),
      ],
    );
  }

  Widget _buildWHControls(TgElement selected) {
    final w = _getW(selected);
    final h = _getH(selected);

    if (w == null && h == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                label: 'W',
                value: (w ?? 0).round(),
                onSubmit: (v) => _setWH(selected, w: v.toDouble()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildNumberField(
                label: 'H',
                value: (h ?? w ?? 0).round(),
                onSubmit: (v) => _setWH(selected, h: v.toDouble()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.height_rounded, size: 16, color: Colors.grey),
            Expanded(
              child: Slider(
                value: (w ?? h ?? 60).clamp(18, 400).toDouble(),
                min: 18,
                max: 400,
                divisions: 76,
                onChanged: (v) => _setWH(selected, w: v, h: (selected is TgRect) ? (h ?? v) : v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotationControls(TgElement selected) {
    final rotRad = _getRotation(selected);
    final rotDeg = (rotRad * 180 / math.pi).clamp(-180.0, 180.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Поворот', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),

        Row(
          children: [
            _buildRotationPreset(-45, '↺45°', () => _rotateSelectedDeg(-45)),
            const SizedBox(width: 4),
            _buildRotationPreset(-90, '↺90°', () => _rotateSelectedDeg(-90)),
            const SizedBox(width: 4),
            _buildRotationPreset(0, '0°', () => _setRotationAbs(selected, 0)),
            const SizedBox(width: 4),
            _buildRotationPreset(45, '↻45°', () => _rotateSelectedDeg(45)),
            const SizedBox(width: 4),
            _buildRotationPreset(90, '↻90°', () => _rotateSelectedDeg(90)),
          ],
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: rotDeg.toDouble(),
                min: -180,
                max: 180,
                divisions: 72,
                label: '${rotDeg.round()}°',
                onChanged: (v) => _setRotationAbs(selected, v * math.pi / 180),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: rotDeg.round().toString(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: '°',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
                onFieldSubmitted: (v) {
                  final deg = double.tryParse(v) ?? 0;
                  _setRotationAbs(selected, deg * math.pi / 180);
                },
              ),
            ),
          ],
        ),

        if (_getOpacity(selected) != null) ...[
          const SizedBox(height: 14),
          _buildOpacityControl(selected),
        ],
      ],
    );
  }

  Widget _buildRotationPreset(double deg, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Center(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransformButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionChip(
          label: 'Сбросить',
          icon: Icons.refresh_rounded,
          onTap: state.resetSelectedTransform,
          color: Colors.grey.shade200,
        ),
        _buildActionChip(
          label: 'На передний',
          icon: Icons.vertical_align_top_rounded,
          onTap: state.bringToFront,
        ),
        _buildActionChip(
          label: 'На задний',
          icon: Icons.vertical_align_bottom_rounded,
          onTap: state.sendToBack,
        ),
      ],
    );
  }

  Widget _buildAppearancePanel(TgElement selected) {
    return Column(
      children: [
        if (_supportsFill(selected))
          _buildColorControl(
            label: 'Заливка / Цвет',
            color: _getFillColor(selected),
            onColorSelected: (c) => _updateFillColor(selected, c),
          ),
        if (_supportsFill(selected) && _supportsStroke(selected)) const SizedBox(height: 14),
        if (_supportsStroke(selected))
          _buildColorControl(
            label: 'Обводка',
            color: _getStrokeColor(selected),
            onColorSelected: (c) => _updateStrokeColor(selected, c),
          ),
        if (_supportsStroke(selected)) ...[
          const SizedBox(height: 14),
          _buildStrokeWidthControl(selected),
        ],
      ],
    );
  }

  Widget _buildStrokeWidthControl(TgElement selected) {
    double w = 2;
    if (selected is TgLine) w = selected.width;
    if (selected is TgRect) w = selected.borderWidth;
    if (selected is TgCircle) w = selected.borderWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Толщина', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: Text('${w.round()}px', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: w.clamp(1, 24).toDouble(),
          min: 1,
          max: 24,
          divisions: 23,
          onChanged: (v) => _updateStrokeWidth(selected, v),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [1, 2, 3, 5, 8, 12].map((p) {
            final sel = w.round() == p;
            return ChoiceChip(
              label: Text('$p'),
              selected: sel,
              onSelected: (_) => _updateStrokeWidth(selected, p.toDouble()),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOpacityControl(TgElement selected) {
    final op = _getOpacity(selected) ?? 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Прозрачность', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: Text('${(op * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: op.clamp(0.05, 1.0),
          min: 0.05,
          max: 1.0,
          divisions: 19,
          onChanged: (v) => _setOpacity(selected, v),
        ),
      ],
    );
  }

  Widget _buildTypographyPanel(TgText text) {
    return Column(
      children: [
        TextField(
          controller: _textController,
          focusNode: _textFieldFocus,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            labelText: 'Текст',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          onChanged: (v) => state.updateSelectedText(text: v),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.text_fields_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: text.size.clamp(10, 60),
                min: 10,
                max: 60,
                divisions: 25,
                onChanged: (v) => state.updateSelectedText(size: v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              child: TextFormField(
                initialValue: text.size.round().toString(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'px',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                onFieldSubmitted: (v) {
                  final s = double.tryParse(v) ?? text.size;
                  state.updateSelectedText(size: s);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTextStyleButton(
              label: 'Обычный',
              isSelected: text.style == TgTextStyle.normal,
              onTap: () => state.updateSelectedText(style: TgTextStyle.normal),
            ),
            _buildTextStyleButton(
              label: 'B',
              isSelected: text.style == TgTextStyle.bold,
              onTap: () => state.updateSelectedText(style: TgTextStyle.bold),
              fontWeight: FontWeight.w900,
            ),
            _buildTextStyleButton(
              label: 'I',
              isSelected: text.style == TgTextStyle.italic,
              onTap: () => state.updateSelectedText(style: TgTextStyle.italic),
              fontStyle: FontStyle.italic,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextStyleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    return Material(
      color: isSelected ? const Color(0xFFE7F3EA) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? const Color(0xFF00A750) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: fontWeight ?? FontWeight.w600, fontStyle: fontStyle),
          ),
        ),
      ),
    );
  }

  Widget _buildLinePropertiesPanel(TgLine line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Тип линии', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chipEnum<LineKind>('Обычная', LineKind.normal, line.kind, (v) => state.updateSelectedLine(kind: v)),
            _chipEnum<LineKind>('Пунктир', LineKind.dashed, line.kind, (v) => state.updateSelectedLine(kind: v)),
            _chipEnum<LineKind>('Волна', LineKind.wavy, line.kind, (v) => state.updateSelectedLine(kind: v)),
          ],
        ),
        const SizedBox(height: 14),

        const Text('Изгиб', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chipEnum<LineCurvature>('Прямая', LineCurvature.straight, line.curvature,
                (v) => state.updateSelectedLine(curvature: v)),
            _chipEnum<LineCurvature>('Кривая', LineCurvature.curved, line.curvature,
                (v) => state.updateSelectedLine(curvature: v)),
          ],
        ),
        const SizedBox(height: 14),

        const Text('Конец', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chipEnum<LineEnd>('Нет', LineEnd.none, line.end, (v) => state.updateSelectedLine(end: v)),
            _chipEnum<LineEnd>('Стрелка', LineEnd.arrow, line.end, (v) => state.updateSelectedLine(end: v)),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            const Text('Стрелка', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text('${line.arrowSize.round()}px', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
        Slider(
          value: line.arrowSize.clamp(6, 80),
          min: 6,
          max: 80,
          divisions: 37,
          onChanged: (v) => state.updateSelectedLine(arrow: v),
        ),
      ],
    );
  }

  Widget _chipEnum<T extends Enum>(String label, T value, T current, ValueChanged<T> onSel) {
    return ChoiceChip(
      label: Text(label),
      selected: value == current,
      onSelected: (_) => onSel(value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStampPropertiesPanel(TgStamp stamp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Asset', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(stamp.asset, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        Row(
          children: [
            const Text('Размер', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text('${stamp.size.round()}px', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
        Slider(
          value: stamp.size.clamp(18, 260),
          min: 18,
          max: 260,
          divisions: 121,
          onChanged: (v) => _setWH(stamp, w: v, h: v),
        ),
      ],
    );
  }

  Widget _buildEffectsPanel(TgElement selected) {
    // Заглушка — под тень/blur/outline, если захочешь.
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Тень (в планах)'),
          value: false,
          onChanged: (_) {},
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Размытие (в планах)'),
          value: false,
          onChanged: (_) {},
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildAdvancedPanel(TgElement selected) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          title: const Text('ID объекта'),
          subtitle: Text(selected.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(height: 24),
        ListTile(
          dense: true,
          leading: const Icon(Icons.center_focus_strong_rounded, size: 16, color: Colors.grey),
          title: const Text('Сброс трансформации'),
          onTap: state.resetSelectedTransform,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ==================== TOOL PANELS (INFO) ====================

  Widget _buildSelectPanel() {
    return _buildInfoPanel(
      title: 'Выделение',
      description: '• Тап — выбрать\n• Перетаскивание — двигать\n• Ctrl+D — дублировать\n• Del — удалить',
      icon: Icons.near_me_rounded,
    );
  }

  Widget _buildLineToolPanel() {
    return _buildInfoPanel(
      title: 'Линии и стрелки',
      description: 'Выбери инструмент вверху (правой панели) или через хоткей.\n\n'
          '• Линия / стрелка\n• Пунктир / волна\n• Конец: стрелка/нет',
      icon: Icons.timeline_rounded,
    );
  }

  Widget _buildTextToolPanel() {
    return _buildInfoPanel(
      title: 'Текст',
      description: '• Добавь текст на поле\n• Меняй размер и стиль\n• Поворачивай как объект',
      icon: Icons.title_rounded,
    );
  }

  Widget _buildShapeToolPanel() {
    return _buildInfoPanel(
      title: 'Фигуры',
      description: '• Прямоугольник / круг\n• Цвет заливки и обводки\n• Поворот',
      icon: Icons.crop_square_rounded,
    );
  }

  Widget _buildStampsToolPanel() {
    // Тут ты потом подключишь реальные assets (список из твоих stamps)
    final demo = <String>[
      'assets/training/stamps/props/ball.png',
      'assets/training/stamps/props/cone.png',
      'assets/training/stamps/props/marker.png',
      'assets/training/stamps/props/bench.png',
      'assets/training/stamps/props/goal.png',
      'assets/training/stamps/props/dummy.png',
      'assets/training/stamps/props/ladder.png',
      'assets/training/stamps/props/pole.png',
      'assets/training/stamps/props/ring.png',
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск объектов...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: demo.length,
            itemBuilder: (_, i) {
              final asset = demo[i];
              return Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => state.setActiveStamp(asset),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sports_soccer_rounded, size: 28, color: Colors.grey),
                        const SizedBox(height: 6),
                        Text(
                          asset.split('/').last,
                          style: const TextStyle(fontSize: 9),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== PALETTE / LAYERS / HISTORY ====================

  Widget _buildPalettePanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Недавние', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          _buildColorGrid(_recentColors),
          const SizedBox(height: 16),
          const Text('Основные', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          _buildColorGrid([
            Colors.black,
            Colors.white,
            Colors.grey.shade800,
            Colors.grey.shade600,
            Colors.red,
            Colors.orange,
            Colors.amber,
            Colors.yellow,
            Colors.green,
            const Color(0xFF00A750),
            Colors.teal,
            Colors.cyan,
            Colors.blue,
            Colors.indigo,
            Colors.purple,
            Colors.pink,
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showAdvancedColorPicker(),
            icon: const Icon(Icons.colorize_rounded),
            label: const Text('Выбрать свой цвет'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
          ),
        ],
      ),
    );
  }

  Widget _buildLayersPanel() {
    // Реально слои можно сделать позже, сейчас — список элементов сверху вниз.
    final items = state.elements.reversed.toList(); // сверху самые верхние
    final selectedIds = state.selectedIds;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final e = items[i];
        final isSel = selectedIds.contains(e.id);

        return Material(
          color: isSel ? const Color(0xFFE7F3EA) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => state.selectById(e.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(_iconForElement(e), size: 18, color: isSel ? const Color(0xFF00A750) : Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getElementTypeName(e),
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey.shade900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '#${e.id.substring(0, e.id.length >= 4 ? 4 : e.id.length)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconForElement(TgElement e) {
    if (e is TgLine) return Icons.timeline_rounded;
    if (e is TgText) return Icons.title_rounded;
    if (e is TgRect) return Icons.crop_square_rounded;
    if (e is TgCircle) return Icons.circle_outlined;
    if (e is TgStamp) return Icons.sports_soccer_rounded;
    return Icons.extension;
  }

  Widget _buildHistoryPanel() {
    // История в TgState — undo/redo стеки закрыты (private). Поэтому тут — панель действий.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.undo_rounded,
            title: 'Undo',
            subtitle: 'Отменить (Ctrl+Z)',
            enabled: state.canUndo,
            onTap: state.undo,
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.redo_rounded,
            title: 'Redo',
            subtitle: 'Повторить (Ctrl+Y)',
            enabled: state.canRedo,
            onTap: state.redo,
          ),
          const SizedBox(height: 18),
          _buildActionTile(
            icon: Icons.refresh_rounded,
            title: 'Сброс вида',
            subtitle: 'Сбросить масштаб и позицию',
            enabled: true,
            onTap: state.resetViewportTransform,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== UI HELPERS ====================

  Widget _buildNumberField({
    required String label,
    required int value,
    required ValueChanged<int> onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          Expanded(
            child: TextFormField(
              initialValue: value.toString(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 6),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              onFieldSubmitted: (v) => onSubmit(int.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorControl({
    required String label,
    required Color color,
    required ValueChanged<Color> onColorSelected,
  }) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => _showColorPicker(color, onColorSelected),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: hex,
                decoration: InputDecoration(
                  hintText: '#000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                onFieldSubmitted: (v) {
                  try {
                    final clean = v.trim().replaceAll('#', '');
                    if (clean.length != 6) return;
                    final c = Color(int.parse('0xFF$clean'));
                    onColorSelected(c);
                  } catch (_) {}
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildColorGrid(_recentColors, onTap: onColorSelected, selected: color),
      ],
    );
  }

  Widget _buildColorGrid(
    List<Color> colors, {
    ValueChanged<Color>? onTap,
    Color? selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        final isSel = selected != null && c.value == selected.value;
        return GestureDetector(
          onTap: () {
            if (onTap != null) onTap(c);
            _setColorToSelected(c);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSel ? Colors.black : Colors.grey.shade300, width: isSel ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollapsiblePanel({
    required String id,
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    final isExpanded = _panelExpanded[id] ?? initiallyExpanded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _panelExpanded[id] = !isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: color ?? Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(color: Colors.grey, height: 1.35), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(width: 1, color: Colors.grey.shade300);

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 10)),
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
      ],
    );
  }

  // ==================== MODEL ADAPTER (AAA CORE) ====================

  double _getX(TgElement e) {
    if (e is TgText) return e.pos.dx;
    if (e is TgStamp) return e.pos.dx;
    if (e is TgLine) return Rect.fromPoints(e.a, e.b).left;
    if (e is TgRect) return Rect.fromPoints(e.a, e.b).left;
    if (e is TgCircle) return Rect.fromPoints(e.a, e.b).left;
    return 0;
  }

  double _getY(TgElement e) {
    if (e is TgText) return e.pos.dy;
    if (e is TgStamp) return e.pos.dy;
    if (e is TgLine) return Rect.fromPoints(e.a, e.b).top;
    if (e is TgRect) return Rect.fromPoints(e.a, e.b).top;
    if (e is TgCircle) return Rect.fromPoints(e.a, e.b).top;
    return 0;
  }

  double? _getW(TgElement e) {
    if (e is TgStamp) return e.size;
    if (e is TgRect) return Rect.fromPoints(e.a, e.b).width.abs();
    if (e is TgCircle) return Rect.fromPoints(e.a, e.b).width.abs();
    return null;
  }

  double? _getH(TgElement e) {
    if (e is TgStamp) return e.size;
    if (e is TgRect) return Rect.fromPoints(e.a, e.b).height.abs();
    if (e is TgCircle) return Rect.fromPoints(e.a, e.b).height.abs();
    return null;
  }

  double _getRotation(TgElement e) {
    if (e is TgText) return e.rotation;
    if (e is TgStamp) return e.rotation;
    if (e is TgRect) return e.rotation;
    if (e is TgCircle) return e.rotation;
    return 0.0; // line rotation отдельно (по углу)
  }

  double? _getOpacity(TgElement e) {
    if (e is TgStamp) return e.opacity;
    return null;
  }

  void _setXY(TgElement element, {double? x, double? y}) {
    state.updateElement(element.id, (e) {
      final dx = (x != null) ? (x - _getX(e)) : 0.0;
      final dy = (y != null) ? (y - _getY(e)) : 0.0;
      final d = Offset(dx, dy);

      if (e is TgText) e.pos += d;
      else if (e is TgStamp) e.pos += d;
      else if (e is TgLine) {
        e.a += d;
        e.b += d;
      } else if (e is TgRect) {
        e.a += d;
        e.b += d;
      } else if (e is TgCircle) {
        e.a += d;
        e.b += d;
      }
      return e;
    });
  }

  void _setWH(TgElement element, {double? w, double? h}) {
    state.updateElement(element.id, (e) {
      if (e is TgStamp) {
        if (w != null) e.size = w.clamp(18.0, 260.0);
        return e;
      }

      if (e is TgRect) {
        final r = Rect.fromPoints(e.a, e.b);
        final nw = (w ?? r.width.abs()).clamp(20.0, 2000.0);
        final nh = (h ?? r.height.abs()).clamp(20.0, 2000.0);
        final c = r.center;
        final nr = Rect.fromCenter(center: c, width: nw, height: nh);
        e.a = nr.topLeft;
        e.b = nr.bottomRight;
        return e;
      }

      if (e is TgCircle) {
        final r = Rect.fromPoints(e.a, e.b);
        final target = (w ?? h ?? r.width.abs()).clamp(20.0, 2000.0);
        final c = r.center;
        final nr = Rect.fromCenter(center: c, width: target, height: target);
        e.a = nr.topLeft;
        e.b = nr.bottomRight;
        return e;
      }

      return e;
    });
  }

  void _rotateSelectedDeg(double deg) {
    final sel = state.selected;
    if (sel == null) return;
    final now = _getRotation(sel);
    final next = now + deg * math.pi / 180;
    _setRotationAbs(sel, next);
  }

  void _setRotationAbs(TgElement element, double radians) {
    // используем готовый метод TgState (он умеет и линию крутить, если ты сделал)
    state.setSelectedRotationAbsolute(radians);
  }

  void _setOpacity(TgElement element, double v) {
    state.updateElement(element.id, (e) {
      if (e is TgStamp) e.opacity = v.clamp(0.05, 1.0);
      return e;
    });
  }

  void _updateStrokeWidth(TgElement element, double width) {
    if (element is TgLine) {
      state.updateSelectedLine(width: width);
    } else if (element is TgRect || element is TgCircle) {
      state.updateSelectedShape(borderW: width);
    }
  }

  void _updateFillColor(TgElement element, Color color) {
    if (element is TgText) {
      state.updateSelectedText(color: color);
    } else if (element is TgRect || element is TgCircle) {
      state.updateSelectedShape(fill: color);
    }

    _pushRecent(color);
  }

  void _updateStrokeColor(TgElement element, Color color) {
    if (element is TgLine) {
      state.updateSelectedLine(color: color); // ✅ фикс
    } else if (element is TgRect || element is TgCircle) {
      state.updateSelectedShape(border: color);
    }

    _pushRecent(color);
  }

  void _pushRecent(Color c) {
    if (_recentColors.any((x) => x.value == c.value)) return;
    setState(() {
      _recentColors.insert(0, c);
      if (_recentColors.length > 8) _recentColors.removeLast();
    });
  }

  void _setColorToSelected(Color color) {
    final sel = state.selected;
    if (sel == null) return;

    if (_supportsFill(sel)) {
      _updateFillColor(sel, color);
    } else if (_supportsStroke(sel)) {
      _updateStrokeColor(sel, color);
    }
  }

  bool _supportsFill(TgElement element) => element is TgRect || element is TgCircle || element is TgText;
  bool _supportsStroke(TgElement element) => element is TgLine || element is TgRect || element is TgCircle;

  Color _getFillColor(TgElement element) {
    if (element is TgText) return element.color;
    if (element is TgRect) return element.fill;
    if (element is TgCircle) return element.fill;
    return Colors.transparent;
  }

  Color _getStrokeColor(TgElement element) {
    if (element is TgLine) return element.color;
    if (element is TgRect) return element.border;
    if (element is TgCircle) return element.border;
    return Colors.black;
  }

  String _getElementTypeName(TgElement element) {
    if (element is TgLine) return 'Линия';
    if (element is TgText) return 'Текст';
    if (element is TgRect) return 'Прямоугольник';
    if (element is TgCircle) return 'Круг';
    if (element is TgStamp) return 'Штамп';
    return 'Объект';
  }

  IconData _getSectionIcon(ToolSection section) {
    switch (section) {
      case ToolSection.select:
        return Icons.near_me_rounded;
      case ToolSection.line:
        return Icons.timeline_rounded;
      case ToolSection.text:
        return Icons.title_rounded;
      case ToolSection.shape:
        return Icons.crop_square_rounded;
      case ToolSection.stamps:
        return Icons.sports_soccer_rounded;
      case ToolSection.properties:
        return Icons.tune_rounded;
      case ToolSection.palette:
        return Icons.palette_outlined;
      case ToolSection.layers:
        return Icons.layers_rounded;
      case ToolSection.history:
        return Icons.history_rounded;
    }
  }

  String _getSectionTitle(ToolSection section) {
    switch (section) {
      case ToolSection.select:
        return 'ВЫДЕЛЕНИЕ';
      case ToolSection.line:
        return 'ЛИНИИ';
      case ToolSection.text:
        return 'ТЕКСТ';
      case ToolSection.shape:
        return 'ФИГУРЫ';
      case ToolSection.stamps:
        return 'ОБЪЕКТЫ';
      case ToolSection.properties:
        return 'СВОЙСТВА';
      case ToolSection.palette:
        return 'ПАЛИТРА';
      case ToolSection.layers:
        return 'СЛОИ';
      case ToolSection.history:
        return 'ИСТОРИЯ';
    }
  }

  // ==================== DIALOGS (simple stubs) ====================

  void _showColorPicker(Color initialColor, ValueChanged<Color> onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите цвет'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 100, decoration: BoxDecoration(color: initialColor, borderRadius: BorderRadius.circular(12))),
              const SizedBox(height: 12),
              const Text('Здесь можно подключить flutter_colorpicker'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              onColorSelected(initialColor);
              Navigator.pop(context);
            },
            child: const Text('Выбрать'),
          ),
        ],
      ),
    );
  }

  void _showAdvancedColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбор цвета'),
        content: const SizedBox(
          width: 300,
          height: 180,
          child: Center(child: Text('Подключи flutter_colorpicker для полного выбора')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ок')),
        ],
      ),
    );
  }
}
