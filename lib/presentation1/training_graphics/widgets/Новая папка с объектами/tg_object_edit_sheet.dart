// lib/presentation/training_graphics/widgets/tg_object_edit_sheet.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../training_graphics_state.dart';
import '../tg_models.dart';

class TgObjectEditSheet extends StatefulWidget {
  const TgObjectEditSheet({super.key, required this.state});
  final TgState state;

  @override
  State<TgObjectEditSheet> createState() => _TgObjectEditSheetState();
}

class _TgObjectEditSheetState extends State<TgObjectEditSheet> {
  TgState get state => widget.state;

  final _textCtrl = TextEditingController();
  String? _lastEditingId;

  // panel behavior
  bool _collapsed = false;
  bool _pinned = false; // если true — не авто-переезжает от объекта
  Offset? _dragOffset; // позиция панели (если таскали)

  // sections
  bool _showTransform = true;
  bool _showStyle = true;
  bool _showPalette = true;
  bool _showAdvanced = false;

  // extra (optional)
  double _dashLen = 10; // для пунктира (если поддержишь в TgState)
  double _dashGap = 8;

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
  }

  void _onState() {
    if (!mounted) return;

    final sel = state.selected;
    if (sel is TgText) {
      if (_lastEditingId != sel.id) {
        _lastEditingId = sel.id;
        _textCtrl.text = sel.text;
      } else {
        if (_textCtrl.text != sel.text) _textCtrl.text = sel.text;
      }
    } else {
      _lastEditingId = null;
    }

    // если выделение поменялось и панель не перетаскивали — сбросим авто-позицию
    if (_dragOffset == null && !_pinned) {
      setState(() {});
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    state.removeListener(_onState);
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;
    if (sel == null) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screen = mq.size;

    final panelW = _collapsed ? 64.0 : 340.0;
    final panelH = math.min(screen.height * 0.78, 620.0);

    // Позиция выбранного объекта (best-effort)
    final obj = _tryGetSelectedScreenPoint(sel);

    // Авто позиция: ставим панель так, чтобы НЕ накрывала объект.
    Offset auto = _computeAutoOffset(
      screen: screen,
      panelSize: Size(panelW, panelH),
      obj: obj,
      padding: const EdgeInsets.all(10),
      safeTop: mq.padding.top + 8,
      safeBottom: mq.padding.bottom + 8,
    );

    Offset pos = _dragOffset ?? auto;

    // clamp to screen
    pos = Offset(
      pos.dx.clamp(10.0, screen.width - panelW - 10.0),
      pos.dy.clamp(mq.padding.top + 8.0, screen.height - panelH - mq.padding.bottom - 8.0),
    );

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: panelW,
            height: panelH,
            child: _panel(sel, panelW, panelH),
          ),
        ],
      ),
    );
  }

  // =========================
  // PANEL
  // =========================
  Widget _panel(TgElement sel, double w, double h) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEDED)),
          boxShadow: const [
            BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Color(0x22000000)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(sel),
            const Divider(height: 1),
            Expanded(
              child: _collapsed
                  ? _collapsedBody(sel)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _section(
                            title: "Transform",
                            icon: Icons.open_with_rounded,
                            open: _showTransform,
                            onTap: () => setState(() => _showTransform = !_showTransform),
                            child: _transformBlock(sel),
                          ),
                          const SizedBox(height: 10),
                          _section(
                            title: "Style",
                            icon: Icons.brush_rounded,
                            open: _showStyle,
                            onTap: () => setState(() => _showStyle = !_showStyle),
                            child: _styleBlock(sel),
                          ),
                          const SizedBox(height: 10),
                          _section(
                            title: "Palette",
                            icon: Icons.palette_outlined,
                            open: _showPalette,
                            onTap: () => setState(() => _showPalette = !_showPalette),
                            child: _paletteBlock(sel),
                          ),
                          const SizedBox(height: 10),
                          _section(
                            title: "Advanced",
                            icon: Icons.tune_rounded,
                            open: _showAdvanced,
                            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                            child: _advancedBlock(),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(TgElement sel) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        // начать drag — фиксируем, что теперь позиция ручная
        if (!_pinned) setState(() => _pinned = true);
      },
      onPanUpdate: (d) {
        setState(() {
          _dragOffset = (_dragOffset ?? const Offset(40, 120)) + d.delta;
        });
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            // drag handle icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: const Icon(Icons.drag_indicator_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _titleFor(sel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
            _pill(_shortType(sel)),
            const SizedBox(width: 8),

            // pin/unpin auto move
            _iconBtn(
              _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              () => setState(() {
                _pinned = !_pinned;
                if (!_pinned) _dragOffset = null; // вернуться к авто-позиции
              }),
              tooltip: _pinned ? "Открепить (авто-позиция)" : "Закрепить (ручная позиция)",
            ),
            const SizedBox(width: 6),

            // collapse
            _iconBtn(
              _collapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
              () => setState(() => _collapsed = !_collapsed),
              tooltip: _collapsed ? "Развернуть" : "Свернуть",
            ),
            const SizedBox(width: 6),

            // ✅ CLOSE (крестик)
            _iconBtn(
              Icons.close_rounded,
              () {
                if (!_tryClearSelection()) {
                  _snack("Нужно добавить метод снятия выделения в TgState (например clearSelection())");
                }
              },
              tooltip: "Закрыть редактор",
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapsedBody(TgElement sel) {
    // мини быстрые штуки — чтобы не мешало смотреть объект
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _miniAction("Undo", Icons.undo_rounded, state.canUndo ? state.undo : null)),
              const SizedBox(width: 8),
              Expanded(child: _miniAction("Redo", Icons.redo_rounded, state.canRedo ? state.redo : null)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniAction("Копия", Icons.copy_rounded, state.duplicateSelected)),
              const SizedBox(width: 8),
              Expanded(child: _miniAction("Удалить", Icons.delete_outline_rounded, state.deleteSelected)),
            ],
          ),
          const Spacer(),
          const Text(
            "Потяни за шапку, чтобы увести панель от объекта.\nНажми развернуть — полный редактор.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12, height: 1.25),
          ),
        ],
      ),
    );
  }

  // =========================
  // BLOCKS
  // =========================

  Widget _transformBlock(TgElement sel) {
    final kids = <Widget>[
      ElevatedButton.icon(
        onPressed: () => state.resetSelectedTransform(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00A750),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
        label: const Text("Сброс трансформаций",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 12),
    ];

    if (sel is TgStamp) {
      kids.addAll([
        _h("Размер"),
        _rowPills(
          left: () => state.bumpSelectedStampSize(-6),
          right: () => state.bumpSelectedStampSize(6),
          mid: Slider(
            value: sel.size.clamp(18, 260),
            min: 18,
            max: 260,
            onChanged: (v) => state.changeSelectedStampSize(v),
          ),
        ),
        const SizedBox(height: 12),
        _h("Поворот"),
        _rowPills(
          leftText: "⟲",
          rightText: "⟳",
          left: () => state.rotateSelectedStamp(-0.18),
          right: () => state.rotateSelectedStamp(0.18),
          mid: Slider(
            value: sel.rotation.clamp(-3.14, 3.14),
            min: -3.14,
            max: 3.14,
            onChanged: (v) => state.setSelectedRotationAbsolute(v),
          ),
        ),
        const SizedBox(height: 12),
        _h("Прозрачность"),
        Slider(
          value: sel.opacity.clamp(0.2, 1.0),
          min: 0.2,
          max: 1.0,
          onChanged: (v) => state.setSelectedStampOpacity(v),
        ),
      ]);
    }

    if (sel is TgLine) {
      kids.addAll([
        _h("Толщина"),
        Slider(
          value: sel.width.clamp(1, 14),
          min: 1,
          max: 14,
          onChanged: (v) => state.updateSelectedLine(width: v),
        ),
        const SizedBox(height: 12),
        _h("Размер стрелки"),
        Slider(
          value: sel.arrowSize.clamp(8, 42),
          min: 8,
          max: 42,
          onChanged: (v) => state.updateSelectedLine(arrow: v),
        ),
      ]);
    }

    if (sel is TgText) {
      kids.addAll([
        _h("Размер текста"),
        Slider(
          value: sel.size.clamp(10, 60),
          min: 10,
          max: 60,
          onChanged: (v) => state.updateSelectedText(size: v),
        ),
      ]);
    }

    if (sel is TgRect || sel is TgCircle) {
      final isRect = sel is TgRect;
      final bw = isRect ? (sel as TgRect).borderWidth : (sel as TgCircle).borderWidth;
      kids.addAll([
        _h("Толщина рамки"),
        Slider(
          value: bw.clamp(1, 14),
          min: 1,
          max: 14,
          onChanged: (v) => state.updateSelectedShape(borderW: v),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
  }

  Widget _styleBlock(TgElement sel) {
    final kids = <Widget>[];

    if (sel is TgLine) {
      kids.addAll([
        _h("Тип линии"),
        const SizedBox(height: 8),
        _choiceWrap<LineKind>(
          current: sel.kind,
          items: const [
            ("Обычная", LineKind.normal),
            ("Пунктир", LineKind.dashed),
            ("Волна", LineKind.wavy),
          ],
          onSelect: (v) => state.updateSelectedLine(kind: v),
        ),
        const SizedBox(height: 12),
        _h("Форма"),
        const SizedBox(height: 8),
        _choiceWrap<LineCurvature>(
          current: sel.curvature,
          items: const [
            ("Прямая", LineCurvature.straight),
            ("Кривая", LineCurvature.curved),
          ],
          onSelect: (v) => state.updateSelectedLine(curvature: v),
        ),
        const SizedBox(height: 12),
        _h("Стрелка"),
        const SizedBox(height: 8),
        _choiceWrap<LineEnd>(
          current: sel.end,
          items: const [
            ("Нет", LineEnd.none),
            ("Стрелка", LineEnd.arrow),
          ],
          onSelect: (v) => state.updateSelectedLine(end: v),
        ),
        const SizedBox(height: 12),

        // Доп-параметры пунктира (опционально — подключишь в TgState)
        if (sel.kind == LineKind.dashed) ...[
          _h("Пунктир: длина/пробел"),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Dash", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Slider(
                      value: _dashLen.clamp(2, 30),
                      min: 2,
                      max: 30,
                      onChanged: (v) => setState(() => _dashLen = v),
                      onChangeEnd: (_) => _tryCallDash(_dashLen, _dashGap),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Gap", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Slider(
                      value: _dashGap.clamp(2, 30),
                      min: 2,
                      max: 30,
                      onChanged: (v) => setState(() => _dashGap = v),
                      onChangeEnd: (_) => _tryCallDash(_dashLen, _dashGap),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ]);
    }

    if (sel is TgText) {
      kids.addAll([
        _h("Текст"),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Введите текст",
            filled: true,
            fillColor: const Color(0xFFF6F7F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (v) => state.updateSelectedText(text: v),
        ),
        const SizedBox(height: 12),
        _h("Стиль"),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _toggle("Обычный", sel.style == TgTextStyle.normal,
                () => state.updateSelectedText(style: TgTextStyle.normal)),
            _toggle("Жирный", sel.style == TgTextStyle.bold,
                () => state.updateSelectedText(style: TgTextStyle.bold)),
            _toggle("Курсив", sel.style == TgTextStyle.italic,
                () => state.updateSelectedText(style: TgTextStyle.italic)),
          ],
        ),
      ]);
    }

    if (sel is TgRect || sel is TgCircle) {
      final isRect = sel is TgRect;
      final kind = isRect ? (sel as TgRect).borderKind : (sel as TgCircle).borderKind;
      kids.addAll([
        _h("Рамка"),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _toggle("Сплошная", kind == BorderKind.solid, () => state.updateSelectedShape(kind: BorderKind.solid)),
            _toggle("Пунктир", kind == BorderKind.dashed, () => state.updateSelectedShape(kind: BorderKind.dashed)),
          ],
        ),
      ]);
    }

    if (kids.isEmpty) {
      kids.add(const Text(
        "Для этого объекта пока нет стилей.",
        style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
  }

  Widget _paletteBlock(TgElement sel) {
    // универсальная палитра (попытаемся применить к линии/тексту/фигуре/штампу)
    final colors = <Color>[
      const Color(0xFF111827),
      const Color(0xFFFFFFFF),
      const Color(0xFF00A750), // Gomel green
      const Color(0xFF0EA5E9),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF6B7280),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Цвет",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((c) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _applyColor(sel, c),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: c == const Color(0xFFFFFFFF)
                    ? const Center(child: Icon(Icons.check_box_outline_blank_rounded, size: 18, color: Color(0xFF9CA3AF)))
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _snack("Если хочешь Color Picker — добавлю через диалог (без пакетов)"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00A750),
            side: const BorderSide(color: Color(0xFF00A750)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.color_lens_outlined),
          label: const Text("Больше цветов", style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _advancedBlock() {
    return const Text(
      "• Перетащи панель за шапку — поставь где удобно.\n"
      "• Закрепи кнопкой-pin — чтобы не прыгала.\n"
      "• Крестик — снять выделение.\n"
      "• Дальше можно добавить точные поля X/Y/Angle/Scale как в проф редакторе.",
      style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, height: 1.25),
    );
  }

  // =========================
  // APPLY COLOR (safe)
  // =========================
  void _applyColor(TgElement sel, Color c) {
    // Пробуем разные методы, если их нет — не падаем.
    // Ты потом скажешь точные поля/методы — подключу идеально.
    bool ok = false;

    if (sel is TgLine) {
      ok = _tryCallDynamic(() => (state as dynamic).updateSelectedLine(color: c));
    } else if (sel is TgText) {
      ok = _tryCallDynamic(() => (state as dynamic).updateSelectedText(color: c));
    } else if (sel is TgStamp) {
      ok = _tryCallDynamic(() => (state as dynamic).setSelectedStampColor(c));
    } else if (sel is TgRect || sel is TgCircle) {
      ok = _tryCallDynamic(() => (state as dynamic).updateSelectedShape(color: c));
    }

    if (!ok) _snack("Цвет пока не подключён в TgState (добавим метод — сделаю 1:1)");
  }

  void _tryCallDash(double dash, double gap) {
    // пример: updateSelectedLine(dash: dash, gap: gap)
    final ok = _tryCallDynamic(() => (state as dynamic).updateSelectedLine(dash: dash, gap: gap));
    if (!ok) _snack("Параметры пунктира пока не поддержаны в TgState");
  }

  bool _tryClearSelection() {
    // Популярные варианты — попробуем несколько.
    if (_tryCallDynamic(() => (state as dynamic).clearSelection())) return true;
    if (_tryCallDynamic(() => (state as dynamic).unselect())) return true;
    if (_tryCallDynamic(() => (state as dynamic).setSelected(null))) return true;
    if (_tryCallDynamic(() => (state as dynamic).select(null))) return true;
    return false;
  }

  bool _tryCallDynamic(Function fn) {
    try {
      fn();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(milliseconds: 1200)),
    );
  }

  // =========================
  // AUTO POSITION (avoid covering object)
  // =========================
  Offset _computeAutoOffset({
    required Size screen,
    required Size panelSize,
    required Offset? obj,
    required EdgeInsets padding,
    required double safeTop,
    required double safeBottom,
  }) {
    // default: справа сверху
    Offset best = Offset(screen.width - panelSize.width - padding.right, safeTop + 30);

    if (_pinned) return _dragOffset ?? best;
    if (obj == null) return best;

    // кандидаты: 4 угла вокруг объекта
    final candidates = <Offset>[
      Offset(padding.left, safeTop + 40), // left top
      Offset(screen.width - panelSize.width - padding.right, safeTop + 40), // right top
      Offset(padding.left, screen.height - panelSize.height - safeBottom - 20), // left bottom
      Offset(screen.width - panelSize.width - padding.right, screen.height - panelSize.height - safeBottom - 20), // right bottom
    ];

    // выбираем позицию, где точка объекта не попадает внутрь панели
    for (final c in candidates) {
      final r = Rect.fromLTWH(c.dx, c.dy, panelSize.width, panelSize.height);
      if (!r.inflate(14).contains(obj)) {
        best = c;
        break;
      }
    }

    return best;
  }

  Offset? _tryGetSelectedScreenPoint(TgElement sel) {
    // best-effort: p / pos / center / x,y
    try {
      final d = sel as dynamic;
      final v = d.p;
      if (v is Offset) return v;
    } catch (_) {}
    try {
      final d = sel as dynamic;
      final v = d.pos;
      if (v is Offset) return v;
    } catch (_) {}
    try {
      final d = sel as dynamic;
      final v = d.center;
      if (v is Offset) return v;
    } catch (_) {}
    try {
      final d = sel as dynamic;
      final vx = d.x;
      final vy = d.y;
      if (vx is num && vy is num) return Offset(vx.toDouble(), vy.toDouble());
    } catch (_) {}
    return null;
  }

  // =========================
  // UI helpers
  // =========================
  Widget _section({
    required String title,
    required IconData icon,
    required bool open,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: open ? 0.5 : 0.0,
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: child),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {String? tooltip}) {
    final enabled = onTap != null;
    final btn = Material(
      color: enabled ? const Color(0xFFF6F7F8) : const Color(0xFFF6F7F8).withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: const Color(0xFF2E2E2E)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  Widget _miniAction(String label, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? const Color(0xFFF6F7F8) : const Color(0xFFF6F7F8).withOpacity(0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
      );

  Widget _rowPills({
    String leftText = "–",
    String rightText = "+",
    required VoidCallback left,
    required VoidCallback right,
    required Widget mid,
  }) {
    return Row(
      children: [
        _pillBtn(leftText, left),
        Expanded(child: mid),
        _pillBtn(rightText, right),
      ],
    );
  }

  Widget _pillBtn(String t, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF6F7F8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _toggle(String title, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE7F3EA) : const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFF00A750) : const Color(0xFFEDEDED)),
        ),
        child: Text(title, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
      ),
    );
  }

  Widget _choiceWrap<T>({
    required T current,
    required List<(String, T)> items,
    required ValueChanged<T> onSelect,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((it) {
        final label = it.$1;
        final value = it.$2;
        final active = value == current;
        return InkWell(
          onTap: () => onSelect(value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE7F3EA) : const Color(0xFFF6F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? const Color(0xFF00A750) : const Color(0xFFEDEDED)),
            ),
            child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
          ),
        );
      }).toList(),
    );
  }

  String _titleFor(TgElement e) {
    if (e is TgStamp) return "Свойства — объект";
    if (e is TgLine) return "Свойства — линия";
    if (e is TgText) return "Свойства — текст";
    if (e is TgRect) return "Свойства — прямоугольник";
    if (e is TgCircle) return "Свойства — круг";
    return "Свойства";
  }

  String _shortType(TgElement e) {
    if (e is TgStamp) return "STAMP";
    if (e is TgLine) return "LINE";
    if (e is TgText) return "TEXT";
    if (e is TgRect) return "RECT";
    if (e is TgCircle) return "CIRCLE";
    return "OBJ";
  }
}
