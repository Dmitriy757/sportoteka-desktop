// lib/presentation/training_graphics/widgets/tg_right_panel.dart
import 'package:flutter/material.dart';

import '../training_graphics_state.dart';
import '../tg_models.dart';
import 'tg_ui_parts.dart';

class TgRightPanel extends StatelessWidget {
  const TgRightPanel({
    super.key,
    required this.state,
  });

  final TgState state;

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;

    final showLine = state.tool == TgTool.line || sel is TgLine;
    final showText = state.tool == TgTool.text || sel is TgText;
    final showShape =
        state.tool == TgTool.rect || state.tool == TgTool.circle || sel is TgRect || sel is TgCircle;

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final sel2 = state.selected;

        final showLine2 = state.tool == TgTool.line || sel2 is TgLine;
        final showText2 = state.tool == TgTool.text || sel2 is TgText;
        final showShape2 = state.tool == TgTool.rect ||
            state.tool == TgTool.circle ||
            sel2 is TgRect ||
            sel2 is TgCircle;

        return Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLine2) _LinesPanel(state: state),
                if (showText2) _TextPanel(state: state),
                if (showShape2) _ShapePanel(state: state),
                if (!showLine2 && !showText2 && !showShape2)
                  const Text(
                    "Выберите инструмент слева\nили выделите элемент на поле",
                    style: TextStyle(color: Color(0xFF7A7A7A)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinesPanel extends StatelessWidget {
  const _LinesPanel({required this.state});
  final TgState state;

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;
    final TgLine? line = sel is TgLine ? sel : null;

    final curvature = line?.curvature ?? state.lineCurvature;
    final kind = line?.kind ?? state.lineKind;
    final end = line?.end ?? state.lineEnd;
    final color = line?.color ?? state.lineColor;
    final width = line?.width ?? state.lineWidth;
    final arrowSize = line?.arrowSize ?? state.arrowSize;

    void setLine({
      LineCurvature? curvature,
      LineKind? kind,
      LineEnd? end,
      Color? color,
      double? width,
      double? arrowSize,
    }) {
      // ✅ update selected object (if any)
      if (line != null) {
        if (curvature != null) line!.curvature = curvature;
        if (kind != null) line!.kind = kind;
        if (end != null) line!.end = end;
        if (color != null) line!.color = color;
        if (width != null) line!.width = width;
        if (arrowSize != null) line!.arrowSize = arrowSize;
      }
      // ✅ update defaults for new elements
      if (curvature != null) state.lineCurvature = curvature;
      if (kind != null) state.lineKind = kind;
      if (end != null) state.lineEnd = end;
      if (color != null) state.lineColor = color;
      if (width != null) state.lineWidth = width;
      if (arrowSize != null) state.arrowSize = arrowSize;

      state.notifyListeners();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TgSectionTitle("Линии"),

        const TgSubTitle("Кривизна"),
        TgChoice2<LineCurvature>(
          value: curvature,
          aValue: LineCurvature.straight,
          bValue: LineCurvature.curved,
          aText: "Прямая",
          bText: "Дуга",
          onChanged: (v) => setLine(curvature: v),
        ),

        const TgSubTitle("Тип линии"),
        TgChoice3<LineKind>(
          value: kind,
          aValue: LineKind.normal,
          bValue: LineKind.dashed,
          cValue: LineKind.wavy,
          aText: "Обычная",
          bText: "Пунктир",
          cText: "Волна",
          onChanged: (v) => setLine(kind: v),
        ),

        const TgSubTitle("Окончание"),
        TgChoice2<LineEnd>(
          value: end,
          aValue: LineEnd.none,
          bValue: LineEnd.arrow,
          aText: "Нет",
          bText: "Стрелка",
          onChanged: (v) => setLine(end: v),
        ),

        const SizedBox(height: 8),
        TgColorRow(
          label: "Цвет",
          value: color,
          onChanged: (c) => setLine(color: c),
        ),

        const SizedBox(height: 8),
        TgStepper(
          label: "Толщина",
          value: width,
          min: 1,
          max: 12,
          step: 1,
          onChanged: (v) => setLine(width: v),
        ),

        const SizedBox(height: 12),
        TgStepper(
          label: "Размер стрелки",
          value: arrowSize,
          min: 6,
          max: 40,
          step: 2,
          onChanged: (v) => setLine(arrowSize: v),
        ),

        const SizedBox(height: 10),
        const Divider(height: 26),
      ],
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({required this.state});
  final TgState state;

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;
    final TgText? text = sel is TgText ? sel : null;

    final style = text?.style ?? state.textStyle;
    final size = text?.size ?? state.textSize;
    final color = text?.color ?? state.textColor;

    void setText({
      TgTextStyle? style,
      double? size,
      Color? color,
    }) {
      if (text != null) {
        if (style != null) text!.style = style;
        if (size != null) text!.size = size;
        if (color != null) text!.color = color;
      }
      if (style != null) state.textStyle = style;
      if (size != null) state.textSize = size;
      if (color != null) state.textColor = color;

      state.notifyListeners();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TgSectionTitle("Текст"),

        const TgSubTitle("Стиль"),
        TgChoice3<TgTextStyle>(
          value: style,
          aValue: TgTextStyle.normal,
          bValue: TgTextStyle.bold,
          cValue: TgTextStyle.italic,
          aText: "Обычный",
          bText: "Жирный",
          cText: "Курсив",
          onChanged: (v) => setText(style: v),
        ),

        const SizedBox(height: 8),
        TgStepper(
          label: "Размер",
          value: size,
          min: 10,
          max: 60,
          step: 2,
          onChanged: (v) => setText(size: v),
        ),

        const SizedBox(height: 12),
        TgColorRow(
          label: "Цвет",
          value: color,
          onChanged: (c) => setText(color: c),
        ),

        const Divider(height: 26),
      ],
    );
  }
}

class _ShapePanel extends StatelessWidget {
  const _ShapePanel({required this.state});
  final TgState state;

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;

    final TgRect? rect = sel is TgRect ? sel : null;
    final TgCircle? circle = sel is TgCircle ? sel : null;

    final isCircle = (state.tool == TgTool.circle || circle != null);
    final title = isCircle ? "Круг" : "Фигура";

    final fill = (rect?.fill ?? circle?.fill) ?? state.fillColor;
    final border = (rect?.border ?? circle?.border) ?? state.borderColor;
    final borderWidth = (rect?.borderWidth ?? circle?.borderWidth) ?? state.borderWidth;
    final borderKind = (rect?.borderKind ?? circle?.borderKind) ?? state.borderKind;

    void setShape({
      Color? fill,
      Color? border,
      double? borderWidth,
      BorderKind? borderKind,
    }) {
      if (rect != null) {
        if (fill != null) rect!.fill = fill;
        if (border != null) rect!.border = border;
        if (borderWidth != null) rect!.borderWidth = borderWidth;
        if (borderKind != null) rect!.borderKind = borderKind;
      }
      if (circle != null) {
        if (fill != null) circle!.fill = fill;
        if (border != null) circle!.border = border;
        if (borderWidth != null) circle!.borderWidth = borderWidth;
        if (borderKind != null) circle!.borderKind = borderKind;
      }

      if (fill != null) state.fillColor = fill;
      if (border != null) state.borderColor = border;
      if (borderWidth != null) state.borderWidth = borderWidth;
      if (borderKind != null) state.borderKind = borderKind;

      state.notifyListeners();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TgSectionTitle(title),

        TgColorRow(
          label: "Заливка",
          value: fill,
          allowTransparent: true,
          onChanged: (c) {
            final v = c == Colors.transparent ? Colors.transparent : c.withOpacity(0.22);
            setShape(fill: v);
          },
        ),

        const SizedBox(height: 4),
        TgColorRow(
          label: "Контур",
          value: border,
          onChanged: (c) => setShape(border: c),
        ),

        const SizedBox(height: 8),
        TgStepper(
          label: "Толщина контура",
          value: borderWidth,
          min: 1,
          max: 12,
          step: 1,
          onChanged: (v) => setShape(borderWidth: v),
        ),

        const TgSubTitle("Тип контура"),
        TgChoice2<BorderKind>(
          value: borderKind,
          aValue: BorderKind.solid,
          bValue: BorderKind.dashed,
          aText: "Сплошной",
          bText: "Пунктир",
          onChanged: (v) => setShape(borderKind: v),
        ),
      ],
    );
  }
}
