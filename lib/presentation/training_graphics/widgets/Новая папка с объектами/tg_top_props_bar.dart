import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgTopPropsBar extends StatelessWidget {
  const TgTopPropsBar({
    super.key,
    required this.state,
    required this.onRequestEditSelected,
  });

  final TgState state;
  final VoidCallback onRequestEditSelected;

  static const _bg = Color(0xFF1C1C1C);
  static const _bd = Color(0xFF141414);
  static const _txtDim = Color(0xFF9CA3AF);

  static const List<Color> _palette = <Color>[
    Color(0xFF111827),
    Color(0xFF2E2E2E),
    Color(0xFFFFFFFF),
    Color(0xFF00A750),
    Color(0xFF2563EB),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final sel = state.selected;

        return Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: _bg,
            border: Border(bottom: BorderSide(color: _bd, width: 1)),
          ),
          child: Row(
            children: [
              _chip(sel == null ? "Выбери объект" : _selectedLabel(sel)),
              const SizedBox(width: 10),
              Expanded(
                child: sel == null
                    ? const Text(
                        "Нажми по объекту — появятся свойства (цвет, пунктир, обводка, стрелки, прозрачность...)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _txtDim, fontSize: 12, fontWeight: FontWeight.w700),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: _propsFor(sel)),
                      ),
              ),
              const SizedBox(width: 10),
              if (sel != null) ...[
                _iconBtn(Icons.tune_rounded, "Редактировать (sheet)", onRequestEditSelected),
                _iconBtn(Icons.copy_rounded, "Дублировать", state.duplicateSelected),
                _iconBtn(Icons.delete_outline_rounded, "Удалить", state.deleteSelected),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _propsFor(TgElement e) {
    if (e is TgLine) return _lineProps(e);
    if (e is TgRect) return _rectProps(e);
    if (e is TgCircle) return _circleProps(e);
    if (e is TgText) return _textProps(e);
    if (e is TgStamp) return _stampProps(e);
    return const [];
  }

  List<Widget> _lineProps(TgLine l) {
    return [
      _colorPicker("Цвет", l.color, (c) => state.updateSelectedLine(color: c)),
      _slider("Толщина", l.width, 1, 20, (v) => state.updateSelectedLine(width: v)),
      _popupLineKind(l.kind, (k) => state.updateSelectedLine(kind: k)),
      _popupLineEnd(l.end, (end) => state.updateSelectedLine(end: end)),
      _slider("Стрелка", l.arrowSize, 0, 30, (v) => state.updateSelectedLine(arrow: v)),
      _rotateQuick(),
    ];
  }

  List<Widget> _rectProps(TgRect r) {
    return [
      _colorPicker(
        "Заливка",
        r.fill.withOpacity(r.opacity),
        (c) => state.updateSelectedShape(fill: c, opacity: c.opacity),
      ),
      _colorPicker("Обводка", r.border, (c) => state.updateSelectedShape(border: c)),
      _slider("Толщ.", r.borderWidth, 0, 20, (v) => state.updateSelectedShape(borderW: v)),
      _popupBorderKind(r.borderKind, (k) => state.updateSelectedShape(kind: k)),
      _slider("Радиус", r.borderRadius, 0, 60, (v) => state.updateSelectedShape(borderRadius: v)),
      _rotateQuick(),
    ];
  }

  List<Widget> _circleProps(TgCircle c) {
    return [
      _colorPicker(
        "Заливка",
        c.fill.withOpacity(c.opacity),
        (col) => state.updateSelectedShape(fill: col, opacity: col.opacity),
      ),
      _colorPicker("Обводка", c.border, (col) => state.updateSelectedShape(border: col)),
      _slider("Толщ.", c.borderWidth, 0, 20, (v) => state.updateSelectedShape(borderW: v)),
      _popupBorderKind(c.borderKind, (k) => state.updateSelectedShape(kind: k)),
      _slider("Радиус", c.radius, 10, 260, (v) => state.updateSelectedShape(radius: v)),
      _rotateQuick(),
    ];
  }

  List<Widget> _textProps(TgText t) {
    return [
      _colorPicker(
        "Цвет",
        t.color.withOpacity(t.opacity),
        (c) => state.updateSelectedText(color: c, opacity: c.opacity),
      ),
      _slider("Размер", t.size, 8, 120, (v) => state.updateSelectedText(size: v)),
      _rotateQuick(),
    ];
  }

  List<Widget> _stampProps(TgStamp s) {
    return [
      _slider("Размер", s.size, 20, 200, (v) => state.setSelectedStampSize(v)),
      _slider("Прозр.", s.opacity * 100, 0, 100, (v) => state.setSelectedStampOpacity(v / 100)),
      _rotateQuick(),
    ];
  }

  Widget _rotateQuick() {
    return Row(
      children: [
        const SizedBox(width: 10),
        _miniBtn("↺", () => state.rotateSelected((-15) * math.pi / 180)),
        const SizedBox(width: 6),
        _miniBtn("↻", () => state.rotateSelected((15) * math.pi / 180)),
        const SizedBox(width: 6),
        _miniBtn("0°", () => state.setSelectedRotationAbsolute(0)),
      ],
    );
  }

  // ---------------- UI bits
  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF343434),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bd),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: EdgeInsets.zero,
    );
  }

  Widget _miniBtn(String t, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bd),
        ),
        child: Text(
          t,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
        ),
      ),
    );
  }

  // ✅ было doubleLine -> стало double
  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        SizedBox(
          width: 120,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.white,
              inactiveTrackColor: _txtDim.withOpacity(0.3),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorPicker(String label, Color current, ValueChanged<Color> onPick) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        _dot(current),
        const SizedBox(width: 6),
        for (final c in _palette) ...[
          _pick(c, active: c.value == current.withOpacity(1).value, onTap: () => onPick(c)),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF111111), width: 2),
      ),
    );
  }

  Widget _pick(Color c, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: active ? Colors.white : const Color(0xFF111111), width: active ? 2 : 1.5),
        ),
      ),
    );
  }

  Widget _popupLineKind(LineKind v, ValueChanged<LineKind> onChanged) {
    return Row(
      children: [
        const SizedBox(width: 10),
        PopupMenuButton<LineKind>(
          initialValue: v,
          onSelected: onChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: LineKind.normal, child: Text("Сплошная")),
            PopupMenuItem(value: LineKind.dashed, child: Text("Пунктир")),
            PopupMenuItem(value: LineKind.dotted, child: Text("Точечная")),
          ],
          child: _pill("Линия: ${_lineKindName(v)}"),
        ),
      ],
    );
  }

  Widget _popupLineEnd(LineEnd v, ValueChanged<LineEnd> onChanged) {
    return Row(
      children: [
        const SizedBox(width: 10),
        PopupMenuButton<LineEnd>(
          initialValue: v,
          onSelected: onChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: LineEnd.none, child: Text("Нет")),
            PopupMenuItem(value: LineEnd.arrow, child: Text("Стрелка")),
            PopupMenuItem(value: LineEnd.diamond, child: Text("Ромб")),
            PopupMenuItem(value: LineEnd.circle, child: Text("Круг")),
          ],
          child: _pill("Конец: ${_lineEndName(v)}"),
        ),
      ],
    );
  }

  Widget _popupBorderKind(BorderKind v, ValueChanged<BorderKind> onChanged) {
    return Row(
      children: [
        const SizedBox(width: 10),
        PopupMenuButton<BorderKind>(
          initialValue: v,
          onSelected: onChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: BorderKind.solid, child: Text("Сплошная")),
            PopupMenuItem(value: BorderKind.dashed, child: Text("Пунктир")),
            PopupMenuItem(value: BorderKind.dotted, child: Text("Точечная")),
            // ✅ правильное имя enum
            PopupMenuItem(value: BorderKind.doubleLine, child: Text("Двойная")),
          ],
          child: _pill("Обводка: ${_borderKindName(v)}"),
        ),
      ],
    );
  }

  Widget _pill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bd),
      ),
      child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  String _selectedLabel(TgElement e) {
    if (e is TgLine) return "Линия";
    if (e is TgRect) return "Прямоугольник";
    if (e is TgCircle) return "Круг";
    if (e is TgText) return "Текст";
    if (e is TgStamp) return "Объект";
    return "Объект";
  }

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
