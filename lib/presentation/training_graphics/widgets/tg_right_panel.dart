import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sportoteka/presentation/training_graphics/tg_models.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';
import 'package:sportoteka/presentation/training_graphics/widgets/tg_canvas.dart';

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
bool _isSvg(String p) => p.toLowerCase().endsWith('.svg');

Widget _stampThumb(String asset) {
  if (_isSvg(asset)) {
    return SvgPicture.asset(
      asset,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      theme: const SvgTheme(currentColor: Colors.transparent),
    );
  }
  return Image.asset(
    asset,
    width: 40,
    height: 40,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
  );
}

// ==================== БАЗОВЫЕ ВИДЖЕТЫ ====================
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _txtDim = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _txt,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: _txtDim,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  static const _border = Color(0xFFE5E7EB);
  static const _green = Color(0xFF00A750);
  static const _txt = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _green.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _green : _border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? _green : _txt,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.colors,
    required this.active,
    required this.onPick,
  });

  final List<Color> colors;
  final Color active;
  final ValueChanged<Color> onPick;

  static const _border = Color(0xFFE5E7EB);
  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        final selected = c.value == active.value;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onPick(c),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _green : _border,
                width: selected ? 2 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.min,
    required this.max,
    required this.value,
    required this.onStart,
    required this.onEnd,
    required this.onChanged,
    this.asPercent = false,
  });

  final String title;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double>? onStart;
  final ValueChanged<double>? onEnd;
  final ValueChanged<double> onChanged;
  final bool asPercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              min: min,
              max: max,
              value: value,
              onChangeStart: onStart,
              onChangeEnd: onEnd,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            asPercent ? '${(value * 100).round()}%' : value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _PillType extends StatelessWidget {
  const _PillType({
    required this.active,
    required this.text,
    required this.onTap,
    required this.green,
  });

  final bool active;
  final String text;
  final VoidCallback onTap;
  final Color green;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? green.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? green : const Color(0xFFE5E7EB),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? green : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ==================== КРУЖОЧКИ ДЛЯ БЫСТРОГО ВЫБОРА ====================
class _QuickActionCircles extends StatelessWidget {
  final TgState state;
  final VoidCallback onObjectSelected;
  final VoidCallback onEditSelected;
  final VoidCallback on3DSelected;
  final bool showEdit;
  final bool is3DActive;
  final bool isObjectActive;
  final bool isEditActive;

  const _QuickActionCircles({
    required this.state,
    required this.onObjectSelected,
    required this.onEditSelected,
    required this.on3DSelected,
    required this.showEdit,
    required this.is3DActive,
    required this.isObjectActive,
    required this.isEditActive,
  });

  static const _green = Color(0xFF00A750);
  static const _bg = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircle(
            icon: Icons.category,
            label: 'Объекты',
            isActive: isObjectActive,
            onTap: onObjectSelected,
          ),
          const SizedBox(height: 12),
          if (state.selected != null)
            _buildCircle(
              icon: Icons.edit,
              label: 'Правка',
              isActive: isEditActive,
              onTap: onEditSelected,
            ),
          const SizedBox(height: 12),
          _buildCircle(
            icon: Icons.threed_rotation,
            label: '3D',
            isActive: is3DActive,
            onTap: on3DSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildCircle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [_green, _green.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.white, _bg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? _green : _border,
              width: isActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : _green,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : _green,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== БАЗОВАЯ ПАНЕЛЬ ====================
class _BasePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onClose;

  const _BasePanel({
    required this.title,
    required this.icon,
    required this.child,
    required this.onClose,
  });

  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_green, _green.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }
}

// ==================== ПАНЕЛЬ ОБЪЕКТОВ ====================
class _ObjectPanel extends _BasePanel {
  final TgState state;
  final List<String> stamps;
  final ValueChanged<String> onObjectSelected;

  _ObjectPanel({
    required this.state,
    required this.stamps,
    required this.onObjectSelected,
    required super.onClose,
  }) : super(
          title: 'Объекты',
          icon: Icons.category,
          child: _ObjectPanelContent(
            state: state,
            stamps: stamps,
            onObjectSelected: onObjectSelected,
          ),
        );
}

class _ObjectPanelContent extends StatefulWidget {
  final TgState state;
  final List<String> stamps;
  final ValueChanged<String> onObjectSelected;

  const _ObjectPanelContent({
    required this.state,
    required this.stamps,
    required this.onObjectSelected,
  });

  @override
  State<_ObjectPanelContent> createState() => _ObjectPanelContentState();
}

class _ObjectPanelContentState extends State<_ObjectPanelContent> {
  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _txtDim = Color(0xFF6B7280);
  static const _green = Color(0xFF00A750);

  final List<CategoryInfo> categories = const [
    CategoryInfo(name: 'Мужчины', path: '/player_m/'),
    CategoryInfo(name: 'Женщины', path: '/player_f/'),
    CategoryInfo(name: 'Тренеры', path: '/coach/'),
    CategoryInfo(name: 'Инвентарь', path: '/props/'),
    CategoryInfo(name: 'Бег', path: '/run_svg/'),
    CategoryInfo(name: 'Пас', path: '/pass_svg/'),
    CategoryInfo(name: 'Стоя', path: '/stand_svg/'),
    CategoryInfo(name: 'Прыжок', path: '/jump_svg/'),
    CategoryInfo(name: 'Вратарь', path: '/vrat_svg/'),
    CategoryInfo(name: 'Ворота', path: '/vorota1/'),
  ];

  int _selectedCategoryIndex = 0;
  final ScrollController _horizontalController = ScrollController();

  String get _activeGroup => categories[_selectedCategoryIndex].name;

  List<String> _groupAssets(String group) {
    final category = categories.firstWhere(
      (c) => c.name == group,
      orElse: () => categories.first,
    );

    return widget.stamps.where((asset) => asset.contains(category.path)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _groupAssets(_activeGroup);

    return Column(
      children: [
        _buildCategories(),
        const SizedBox(height: 12),
        if (items.isEmpty) _buildEmptyState() else _buildGrid(items),
        const SizedBox(height: 12),
        _buildInfo(),
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategoryIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _green : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _green : _border,
                  width: 1,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : _txt,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<String> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final asset = items[i];
        final active = widget.state.activeStampAsset == asset &&
            widget.state.tool == TgTool.stamp;

        return InkWell(
          onTap: () => widget.onObjectSelected(asset),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? _green : _border,
                width: active ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: _stampThumb(asset),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Нет объектов',
        style: TextStyle(color: _txtDim, fontSize: 12),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: _green),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              'Нажмите на объект, затем на поле',
              style: TextStyle(color: _txtDim, fontSize: 10),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ПАНЕЛЬ РЕДАКТОРА ====================
class _EditorPanel extends _BasePanel {
  final TgState state;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;

  _EditorPanel({
    required this.state,
    required this.onRefreshSvg,
    required super.onClose,
  }) : super(
          title: _getTitle(state.selected),
          icon: Icons.edit,
          child: _EditorPanelContent(
            state: state,
            onRefreshSvg: onRefreshSvg,
          ),
        );

  static String _getTitle(TgElement? sel) {
    if (sel == null) return 'Правка';
    if (sel is TgStamp) return 'Объект';
    if (sel is TgLine) return 'Линия';
    if (sel is TgRect) return 'Прямоугольник';
    if (sel is TgCircle) return 'Круг';
    if (sel is TgText) return 'Текст';
    if (sel is TgZigzag) return 'Зигзаг';
    if (sel is TgSpring) return 'Пружинка';
    if (sel is TgSpiral) return 'Спираль';
    if (sel is TgWavy) return 'Волнистая';
    return 'Элемент';
  }
}

class _EditorPanelContent extends StatelessWidget {
  final TgState state;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;

  const _EditorPanelContent({
    required this.state,
    required this.onRefreshSvg,
  });

  static const _colors = <Color>[
    Colors.white,
    Color(0xFF00A750),
    Color(0xFF2F80ED),
    Color(0xFFEB5757),
    Color(0xFFF2C94C),
    Color(0xFF9B51E0),
    Color(0xFF56CCF2),
    Color(0xFFBDBDBD),
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    final sel = state.selected;
    if (sel == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sel is TgLine) _LineEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgStamp)
          _StampEditor(
            state: state,
            sel: sel,
            onRefreshSvg: onRefreshSvg,
          ),
        if (sel is TgRect) _RectEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgCircle)
          _CircleEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgText) _TextEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgEditableCurve)
          _CurveEditor(
            state: state,
            sel: sel,
            colors: _colors,
            txt: const Color(0xFF111827),
            border: const Color(0xFFE5E7EB),
            surface: const Color(0xFFF7F8FA),
            green: const Color(0xFF00A750),
          ),
        if (sel is TgZigzag)
          _ZigzagEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgSpring)
          _SpringEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgSpiral)
          _SpiralEditor(state: state, sel: sel, colors: _colors),
        if (sel is TgWavy) _WavyEditor(state: state, sel: sel, colors: _colors),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.copy,
                label: 'Дубль',
                onTap: state.duplicateSelected,
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Удалить',
                onTap: state.deleteSelected,
                isDestructive: true,
              ),
              _buildActionButton(
                icon: Icons.vertical_align_top,
                label: 'Вперед',
                onTap: state.bringToFront,
              ),
              _buildActionButton(
                icon: Icons.vertical_align_bottom,
                label: 'Назад',
                onTap: state.sendToBack,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFEE2E2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFECACA)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF111827),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF111827),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ПАНЕЛЬ 3D ====================
class _ThreeDPanel extends _BasePanel {
  final TgState state;
  final GlobalKey<TgCanvasState> canvasKey;

  _ThreeDPanel({
    required this.state,
    required this.canvasKey,
    required super.onClose,
  }) : super(
          title: '3D Управление',
          icon: Icons.threed_rotation,
          child: _ThreeDPanelContent(
            state: state,
            canvasKey: canvasKey,
          ),
        );
}

class _ThreeDPanelContent extends StatelessWidget {
  final TgState state;
  final GlobalKey<TgCanvasState> canvasKey;

  const _ThreeDPanelContent({
    required this.state,
    required this.canvasKey,
  });

  static const _green = Color(0xFF00A750);
  static const _txt = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _build3DSlider(
          icon: Icons.arrow_downward,
          label: 'Наклон',
          value: state.rotationX,
          min: -1.55,
          max: 0.0,
          onChanged: (v) => canvasKey.currentState?.setRotationX(v),
        ),
        const SizedBox(height: 16),
        _build3DSlider(
          icon: Icons.rotate_right,
          label: 'Поворот',
          value: state.rotationZ,
          min: -math.pi,
          max: math.pi,
          onChanged: (v) => canvasKey.currentState?.setRotationZ(v),
        ),
        const SizedBox(height: 20),
        _buildDivider(),
        Row(
          children: [
            Expanded(
              child: _buildZoomButton(
                icon: Icons.remove,
                label: 'Уменьшить',
                onTap: () => canvasKey.currentState?.zoomOut(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildZoomButton(
                icon: Icons.add,
                label: 'Увеличить',
                onTap: () => canvasKey.currentState?.zoomIn(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDivider(),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Камера',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _txt,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _buildDpad(
            up: () => canvasKey.currentState?.cameraUp(),
            down: () => canvasKey.currentState?.cameraDown(),
            left: () => canvasKey.currentState?.cameraLeft(),
            right: () => canvasKey.currentState?.cameraRight(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => canvasKey.currentState?.centerView(),
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text('Центр'),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _green.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: () => canvasKey.currentState?.reset3D(),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Сброс'),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _green.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _build3DSlider({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: _green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _txt,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value.clamp(min, max),
                      onChanged: onChanged,
                      min: min,
                      max: max,
                      divisions: 30,
                      activeColor: _green,
                      inactiveColor: _green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label == 'Наклон'
                          ? '${(value.abs() * 50).round()}°'
                          : '${(value * 30).round()}°',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _green),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDpad({
    required VoidCallback up,
    required VoidCallback down,
    required VoidCallback left,
    required VoidCallback right,
  }) {
    Widget _dpadButton(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withOpacity(0.2)),
          ),
          child: Icon(icon, color: _green, size: 24),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dpadButton(Icons.keyboard_arrow_up, up),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dpadButton(Icons.keyboard_arrow_left, left),
            const SizedBox(width: 10),
            _dpadButton(Icons.keyboard_arrow_right, right),
          ],
        ),
        const SizedBox(height: 6),
        _dpadButton(Icons.keyboard_arrow_down, down),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFFE5E7EB),
    );
  }
}

// ==================== РЕДАКТОРЫ ЭЛЕМЕНТОВ ====================
class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgLine sel;
  final List<Color> colors;

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final double lineLength = (sel.b - sel.a).distance;
    final double angleRad = math.atan2(sel.b.dy - sel.a.dy, sel.b.dx - sel.a.dx);
    final double angleDeg = angleRad * 180 / math.pi;

    return Column(
      children: [
        _Section(
          title: 'Режим',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ToggleBtn(
                      text: 'Прямая',
                      active: sel.curveMode == TgLineCurve.straight,
                      onTap: () {
                        state.updateSelectedLine(
                          curveMode: TgLineCurve.straight,
                          curveAmount: 0,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleBtn(
                      text: 'Кривая',
                      active: sel.curveMode == TgLineCurve.curved,
                      onTap: () {
                        state.updateSelectedLine(
                          curveMode: TgLineCurve.curved,
                          curveAmount: 0.5,
                        );
                        state.editSelectedLinePoints();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleBtn(
                text: '✎ Изменить длину на поле',
                active: false,
                onTap: () => state.editLineLength(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Длина',
          trailing: '${lineLength.toStringAsFixed(0)} px',
          child: Slider(
            min: 20,
            max: 500,
            value: lineLength.clamp(20, 500),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (newLength) {
              final center = Offset(
                (sel.a.dx + sel.b.dx) / 2,
                (sel.a.dy + sel.b.dy) / 2,
              );
              final delta = sel.b - sel.a;
              final length = delta.distance;
              final direction = length > 0 ? delta / length : Offset.zero;

              final halfLength = newLength / 2;
              final newA = center - direction * halfLength;
              final newB = center + direction * halfLength;

              state.updateSelectedLine(a: newA, b: newB);
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Поворот',
          trailing: '${angleDeg.round()}°',
          child: Slider(
            min: -180,
            max: 180,
            value: angleDeg.clamp(-180, 180),
            divisions: 36,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (newAngleDeg) {
              final center = Offset(
                (sel.a.dx + sel.b.dx) / 2,
                (sel.a.dy + sel.b.dy) / 2,
              );
              final length = (sel.b - sel.a).distance;
              final newAngleRad = newAngleDeg * math.pi / 180;

              final halfLength = length / 2;
              final newA = Offset(
                center.dx - math.cos(newAngleRad) * halfLength,
                center.dy - math.sin(newAngleRad) * halfLength,
              );
              final newB = Offset(
                center.dx + math.cos(newAngleRad) * halfLength,
                center.dy + math.sin(newAngleRad) * halfLength,
              );

              state.updateSelectedLine(a: newA, b: newB);
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Тип линии',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToggleBtn(
                text: 'Обычная',
                active: sel.kind == LineKind.normal,
                onTap: () => state.updateSelectedLine(kind: LineKind.normal),
              ),
              _ToggleBtn(
                text: 'Пунктир',
                active: sel.kind == LineKind.dashed,
                onTap: () => state.updateSelectedLine(kind: LineKind.dashed),
              ),
              _ToggleBtn(
                text: 'Точечная',
                active: sel.kind == LineKind.dotted,
                onTap: () => state.updateSelectedLine(kind: LineKind.dotted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Окончание',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToggleBtn(
                text: 'Нет',
                active: sel.end == LineEnd.none,
                onTap: () => state.updateSelectedLine(end: LineEnd.none),
              ),
              _ToggleBtn(
                text: 'Стрелка',
                active: sel.end == LineEnd.arrow,
                onTap: () => state.updateSelectedLine(end: LineEnd.arrow),
              ),
              _ToggleBtn(
                text: 'Круг',
                active: sel.end == LineEnd.circle,
                onTap: () => state.updateSelectedLine(end: LineEnd.circle),
              ),
            ],
          ),
        ),
        if (sel.end != LineEnd.none) ...[
          const SizedBox(height: 10),
          _Section(
            title: 'Размер окончания',
            trailing: sel.arrowSize.toStringAsFixed(0),
            child: Slider(
              min: 6,
              max: 44,
              value: sel.arrowSize.clamp(6.0, 44.0),
              onChangeStart: (_) => _lock(true),
              onChangeEnd: (_) => _lock(false),
              onChanged: (v) => state.updateSelectedLine(arrow: v),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedLine(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Толщина',
          trailing: sel.width.toStringAsFixed(1),
          child: Slider(
            min: 1,
            max: 30,
            value: sel.width.clamp(1.0, 30.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedLine(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.1,
            max: 1.0,
            value: sel.opacity.clamp(0.1, 1.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedLine(opacity: v),
          ),
        ),
      ],
    );
  }
}

class _StampEditor extends StatelessWidget {
  const _StampEditor({
    required this.state,
    required this.sel,
    required this.onRefreshSvg,
  });

  final TgState state;
  final TgStamp sel;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final rotDeg = sel.rotation * 180 / math.pi;
    final isSvg = sel.asset.toLowerCase().endsWith('.svg');

    final isPlayerSvg = isSvg &&
        (sel.asset.contains('/run_svg/') ||
            sel.asset.contains('/pass_svg/') ||
            sel.asset.contains('/jump_svg/') ||
            sel.asset.contains('/vrat_svg/') ||
            sel.asset.contains('/stand_svg/'));

    final isPropSvg = isSvg && sel.asset.contains('/props/');

    return Column(
      children: [
        if (isPlayerSvg) ...[
          _PlayerColorEditor(
            state: state,
            sel: sel,
            colors: const [
              Color(0xFF00A750),
              Color(0xFF2F80ED),
              Color(0xFFEB5757),
              Color(0xFFF2C94C),
              Color(0xFF9B51E0),
              Color(0xFF56CCF2),
              Color(0xFFBDBDBD),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (isPropSvg) ...[
          _PropColorEditor(
            state: state,
            sel: sel,
            colors: const [
              Color(0xFF00A750),
              Color(0xFF2F80ED),
              Color(0xFFEB5757),
              Color(0xFFF2C94C),
              Color(0xFF9B51E0),
              Color(0xFF56CCF2),
              Color(0xFFBDBDBD),
            ],
            onRefreshSvg: onRefreshSvg,
          ),
          const SizedBox(height: 10),
        ],
        _Section(
          title: 'Размер',
          trailing: sel.size.toStringAsFixed(0),
          child: Slider(
            min: 20,
            max: 260,
            value: sel.size.clamp(20.0, 260.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: state.setSelectedStampSize,
          ),
        ),
        const SizedBox(height: 10),
        if (!isSvg) ...[
          _Section(
            title: 'Цвет',
            child: _ColorRow(
              colors: const [
                Colors.white,
                Color(0xFF00A750),
                Color(0xFF2F80ED),
                Color(0xFFEB5757),
                Color(0xFFF2C94C),
                Color(0xFF9B51E0),
                Color(0xFF56CCF2),
                Color(0xFFBDBDBD),
                Colors.black,
              ],
              active: sel.color ?? Colors.white,
              onPick: (c) => state.updateSelectedStamp(color: c),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.05,
            max: 1,
            value: sel.opacity.clamp(0.05, 1.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: state.setSelectedStampOpacity,
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Поворот',
          trailing: '${rotDeg.round()}°',
          child: Slider(
            min: -180,
            max: 180,
            value: rotDeg.clamp(-180, 180).toDouble(),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) =>
                state.setSelectedRotationAbsolute(v * math.pi / 180),
          ),
        ),
        if (isSvg && !isPlayerSvg && !isPropSvg) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'SVG сохраняет оригинальные цвета',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

class _RectEditor extends StatelessWidget {
  const _RectEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgRect sel;
  final List<Color> colors;

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: 'Заливка',
          child: _ColorRow(
            colors: colors,
            active: sel.fill,
            onPick: (c) => state.updateSelectedShape(fill: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.05,
            max: 1,
            value: sel.opacity.clamp(0.05, 1.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedShape(opacity: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Обводка',
          child: Column(
            children: [
              _ColorRow(
                colors: colors,
                active: sel.border,
                onPick: (c) => state.updateSelectedShape(border: c),
              ),
              const SizedBox(height: 10),
              _SliderRow(
                title: 'Толщина',
                min: 0,
                max: 18,
                value: sel.borderWidth.clamp(0.0, 18.0),
                onStart: (_) => _lock(true),
                onEnd: (_) => _lock(false),
                onChanged: (v) => state.updateSelectedShape(borderW: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Скругление',
          trailing: sel.borderRadius.toStringAsFixed(0),
          child: Slider(
            min: 0,
            max: 80,
            value: sel.borderRadius.clamp(0.0, 80.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedShape(borderRadius: v),
          ),
        ),
      ],
    );
  }
}

class _CircleEditor extends StatelessWidget {
  const _CircleEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgCircle sel;
  final List<Color> colors;

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: 'Заливка',
          child: _ColorRow(
            colors: colors,
            active: sel.fill,
            onPick: (c) => state.updateSelectedShape(fill: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.05,
            max: 1,
            value: sel.opacity.clamp(0.05, 1.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedShape(opacity: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Обводка',
          child: Column(
            children: [
              _ColorRow(
                colors: colors,
                active: sel.border,
                onPick: (c) => state.updateSelectedShape(border: c),
              ),
              const SizedBox(height: 10),
              _SliderRow(
                title: 'Толщина',
                min: 0,
                max: 18,
                value: sel.borderWidth.clamp(0.0, 18.0),
                onStart: (_) => _lock(true),
                onEnd: (_) => _lock(false),
                onChanged: (v) => state.updateSelectedShape(borderW: v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextEditor extends StatelessWidget {
  const _TextEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgText sel;
  final List<Color> colors;

  static const _txt = Color(0xFF111827);
  static const _txtDim = Color(0xFF6B7280);

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: 'Текст',
          child: TextField(
            controller: TextEditingController(text: sel.text)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: sel.text.length),
              ),
            decoration: InputDecoration(
              hintText: 'Введите текст',
              hintStyle: TextStyle(
                color: _txtDim.withOpacity(0.5),
                fontSize: 12,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(
              color: _txt,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            minLines: 1,
            onChanged: (value) => state.updateSelectedText(text: value),
            onTap: () => state.setLockViewport(true),
            onTapOutside: (_) {
              state.setLockViewport(false);
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Размер',
          trailing: sel.size.toStringAsFixed(0),
          child: Slider(
            min: 8,
            max: 96,
            value: sel.size.clamp(8.0, 96.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedText(size: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedText(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.05,
            max: 1,
            value: sel.opacity.clamp(0.05, 1.0),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedText(opacity: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Выравнивание',
          child: Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  text: 'Left',
                  active: sel.alignment == TextAlign.left,
                  onTap: () => state.updateSelectedText(align: TextAlign.left),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: 'Center',
                  active: sel.alignment == TextAlign.center,
                  onTap: () => state.updateSelectedText(align: TextAlign.center),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: 'Right',
                  active: sel.alignment == TextAlign.right,
                  onTap: () => state.updateSelectedText(align: TextAlign.right),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Стиль',
          child: Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  text: 'Обычный',
                  active: sel.style == TgTextStyle.normal,
                  onTap: () =>
                      state.updateSelectedText(style: TgTextStyle.normal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: 'Жирный',
                  active: sel.weight == FontWeight.bold,
                  onTap: () =>
                      state.updateSelectedText(weight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZigzagEditor extends StatelessWidget {
  const _ZigzagEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgZigzag sel;
  final List<Color> colors;

  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _green = Color(0xFF00A750);

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final isEditable = sel is TgEditableZigzag;
    final editableSel = isEditable ? sel as TgEditableZigzag : null;
    final inEditMode = isEditable && (editableSel?.showControlPoints ?? false);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: inEditMode ? _green.withOpacity(0.15) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inEditMode ? _green : _border,
              width: inEditMode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Режим редактирования',
                style: TextStyle(
                  color: inEditMode ? _green : _txt,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isEditable) {
                          state.editZigzagPoints();
                        } else if (editableSel != null &&
                            !editableSel.showControlPoints) {
                          state.editZigzagPoints();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inEditMode ? _green : Colors.white,
                        foregroundColor: inEditMode ? Colors.white : _green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: inEditMode ? _green : _border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: inEditMode ? Colors.white : _green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            inEditMode
                                ? 'Режим активен'
                                : 'Редактировать точки',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (inEditMode) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final edit = editableSel;
                          if (edit == null) return;

                          final updated = TgZigzag(
                            id: edit.id,
                            start: edit.start,
                            endPoint: edit.endPoint,
                            color: edit.color,
                            width: edit.width,
                            kind: edit.kind,
                            opacity: edit.opacity,
                            amplitude: edit.amplitude,
                            frequency: edit.frequency,
                            phase: edit.phase,
                            lineEnd: edit.lineEnd,
                            arrowSize: edit.arrowSize,
                            locked: edit.locked,
                            hidden: edit.hidden,
                            layer: edit.layer,
                            name: edit.name,
                            createdAt: edit.createdAt,
                          );

                          state.replaceElement(
                            updated,
                            keepSelection: true,
                            setTool: TgTool.select,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Готово',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (inEditMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Перетаскивайте цветные точки на поле для изменения формы зигзага",
                    style: TextStyle(
                      color: _txt,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Section(
          title: 'Высота зубцов',
          trailing: sel.amplitude.toStringAsFixed(0),
          child: Slider(
            min: 5,
            max: 100,
            value: sel.amplitude.clamp(5, 100),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedZigzag(amplitude: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Количество зубцов',
          trailing: sel.frequency.toStringAsFixed(1),
          child: Slider(
            min: 2,
            max: 15,
            value: sel.frequency.clamp(2, 15),
            divisions: 13,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedZigzag(frequency: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedZigzag(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Толщина',
          trailing: sel.width.toStringAsFixed(1),
          child: Slider(
            min: 1,
            max: 30,
            value: sel.width.clamp(1, 30),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedZigzag(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.1,
            max: 1,
            value: sel.opacity.clamp(0.1, 1),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedZigzag(opacity: v),
          ),
        ),
      ],
    );
  }
}

class _WavyEditor extends StatelessWidget {
  const _WavyEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgWavy sel;
  final List<Color> colors;

  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _green = Color(0xFF00A750);

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final isEditable = sel is TgEditableWavy;
    final editableSel = isEditable ? sel as TgEditableWavy : null;
    final inEditMode = isEditable && (editableSel?.showControlPoints ?? false);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: inEditMode ? _green.withOpacity(0.15) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inEditMode ? _green : _border,
              width: inEditMode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Режим редактирования',
                style: TextStyle(
                  color: inEditMode ? _green : _txt,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isEditable) {
                          state.editWavyPoints();
                        } else if (editableSel != null &&
                            !editableSel.showControlPoints) {
                          state.editWavyPoints();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inEditMode ? _green : Colors.white,
                        foregroundColor: inEditMode ? Colors.white : _green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: inEditMode ? _green : _border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: inEditMode ? Colors.white : _green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            inEditMode
                                ? 'Режим активен'
                                : 'Редактировать точки',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (inEditMode) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final edit = editableSel;
                          if (edit == null) return;

                          final updated = TgWavy(
                            id: edit.id,
                            start: edit.start,
                            endPoint: edit.endPoint,
                            controlPoints: edit.controlPoints,
                            color: edit.color,
                            width: edit.width,
                            kind: edit.kind,
                            opacity: edit.opacity,
                            amplitude: edit.amplitude,
                            wavelength: edit.wavelength,
                            phase: edit.phase,
                            lineEnd: edit.lineEnd,
                            arrowSize: edit.arrowSize,
                            cap: edit.cap,
                            join: edit.join,
                            dash: edit.dash,
                            locked: edit.locked,
                            hidden: edit.hidden,
                            layer: edit.layer,
                            name: edit.name,
                            createdAt: edit.createdAt,
                          );

                          state.replaceElement(
                            updated,
                            keepSelection: true,
                            setTool: TgTool.select,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Готово',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (inEditMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Перетаскивайте цветные точки на поле для изменения формы волны",
                    style: TextStyle(
                      color: _txt,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Section(
          title: 'Высота волны',
          trailing: sel.amplitude.toStringAsFixed(0),
          child: Slider(
            min: 5,
            max: 100,
            value: sel.amplitude.clamp(5, 100),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedWavy(amplitude: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Длина волны',
          trailing: sel.wavelength.toStringAsFixed(0),
          child: Slider(
            min: 10,
            max: 100,
            value: sel.wavelength.clamp(10, 100),
            divisions: 45,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedWavy(wavelength: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Фаза',
          trailing: sel.phase.toStringAsFixed(1),
          child: Slider(
            min: 0,
            max: 2 * math.pi,
            value: sel.phase.clamp(0, 2 * math.pi),
            divisions: 20,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedWavy(phase: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Тип линии',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToggleBtn(
                text: 'Обычная',
                active: sel.kind == LineKind.normal,
                onTap: () => state.updateSelectedWavy(kind: LineKind.normal),
              ),
              _ToggleBtn(
                text: 'Пунктир',
                active: sel.kind == LineKind.dashed,
                onTap: () => state.updateSelectedWavy(kind: LineKind.dashed),
              ),
              _ToggleBtn(
                text: 'Точечная',
                active: sel.kind == LineKind.dotted,
                onTap: () => state.updateSelectedWavy(kind: LineKind.dotted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Окончание',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToggleBtn(
                text: 'Нет',
                active: sel.lineEnd == LineEnd.none,
                onTap: () =>
                    state.updateSelectedWavy(lineEnd: LineEnd.none),
              ),
              _ToggleBtn(
                text: 'Стрелка',
                active: sel.lineEnd == LineEnd.arrow,
                onTap: () =>
                    state.updateSelectedWavy(lineEnd: LineEnd.arrow),
              ),
              _ToggleBtn(
                text: 'Круг',
                active: sel.lineEnd == LineEnd.circle,
                onTap: () =>
                    state.updateSelectedWavy(lineEnd: LineEnd.circle),
              ),
            ],
          ),
        ),
        if (sel.lineEnd != LineEnd.none) ...[
          const SizedBox(height: 10),
          _Section(
            title: 'Размер окончания',
            trailing: sel.arrowSize.toStringAsFixed(0),
            child: Slider(
              min: 6,
              max: 44,
              value: sel.arrowSize.clamp(6.0, 44.0),
              onChangeStart: (_) => _lock(true),
              onChangeEnd: (_) => _lock(false),
              onChanged: (v) => state.updateSelectedWavy(arrowSize: v),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedWavy(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Толщина',
          trailing: sel.width.toStringAsFixed(1),
          child: Slider(
            min: 1,
            max: 30,
            value: sel.width.clamp(1, 30),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedWavy(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.1,
            max: 1,
            value: sel.opacity.clamp(0.1, 1),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedWavy(opacity: v),
          ),
        ),
      ],
    );
  }
}

class _SpringEditor extends StatelessWidget {
  const _SpringEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgSpring sel;
  final List<Color> colors;

  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _green = Color(0xFF00A750);

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final isEditable = sel is TgEditableSpring;
    final editableSel = isEditable ? sel as TgEditableSpring : null;
    final inEditMode = isEditable && (editableSel?.showControlPoints ?? false);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: inEditMode ? _green.withOpacity(0.15) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inEditMode ? _green : _border,
              width: inEditMode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Режим редактирования',
                style: TextStyle(
                  color: inEditMode ? _green : _txt,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isEditable) {
                          state.editSpringPoints();
                        } else if (editableSel != null &&
                            !editableSel.showControlPoints) {
                          state.editSpringPoints();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inEditMode ? _green : Colors.white,
                        foregroundColor: inEditMode ? Colors.white : _green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: inEditMode ? _green : _border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: inEditMode ? Colors.white : _green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            inEditMode
                                ? 'Режим активен'
                                : 'Редактировать точки',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (inEditMode) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final edit = editableSel;
                          if (edit == null) return;

                          final updated = TgSpring(
                            id: edit.id,
                            start: edit.start,
                            endPoint: edit.endPoint,
                            color: edit.color,
                            width: edit.width,
                            kind: edit.kind,
                            opacity: edit.opacity,
                            amplitude: edit.amplitude,
                            frequency: edit.frequency,
                            phase: edit.phase,
                            lineEnd: edit.lineEnd,
                            arrowSize: edit.arrowSize,
                            locked: edit.locked,
                            hidden: edit.hidden,
                            layer: edit.layer,
                            name: edit.name,
                            createdAt: edit.createdAt,
                          );

                          state.replaceElement(
                            updated,
                            keepSelection: true,
                            setTool: TgTool.select,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Готово',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (inEditMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Перетаскивайте цветные точки на поле для изменения формы пружинки",
                    style: TextStyle(
                      color: _txt,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Section(
          title: 'Диаметр пружины',
          trailing: sel.amplitude.toStringAsFixed(0),
          child: Slider(
            min: 10,
            max: 60,
            value: sel.amplitude.clamp(10, 60),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpring(amplitude: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Количество витков',
          trailing: sel.frequency.toStringAsFixed(1),
          child: Slider(
            min: 3,
            max: 12,
            value: sel.frequency.clamp(3, 12),
            divisions: 9,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpring(frequency: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedSpring(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Толщина линии',
          trailing: sel.width.toStringAsFixed(1),
          child: Slider(
            min: 1,
            max: 8,
            value: sel.width.clamp(1, 8),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpring(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.1,
            max: 1,
            value: sel.opacity.clamp(0.1, 1),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpring(opacity: v),
          ),
        ),
      ],
    );
  }
}

class _SpiralEditor extends StatelessWidget {
  const _SpiralEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgSpiral sel;
  final List<Color> colors;

  static const _surface = Color(0xFFF7F8FA);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _green = Color(0xFF00A750);

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    final isEditable = sel is TgEditableSpiral;
    final editableSel = isEditable ? sel as TgEditableSpiral : null;
    final inEditMode = isEditable && (editableSel?.showControlPoints ?? false);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: inEditMode ? _green.withOpacity(0.15) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inEditMode ? _green : _border,
              width: inEditMode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Режим редактирования',
                style: TextStyle(
                  color: inEditMode ? _green : _txt,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isEditable) {
                          state.editSpiralPoints();
                        } else if (editableSel != null &&
                            !editableSel.showControlPoints) {
                          state.editSpiralPoints();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inEditMode ? _green : Colors.white,
                        foregroundColor: inEditMode ? Colors.white : _txt,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: inEditMode ? _green : _border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: inEditMode ? Colors.white : _green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            inEditMode
                                ? 'Режим активен'
                                : 'Редактировать точки',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (inEditMode) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final edit = editableSel;
                          if (edit == null) return;

                          final updated = TgSpiral(
                            id: edit.id,
                            start: edit.start,
                            endPoint: edit.endPoint,
                            color: edit.color,
                            width: edit.width,
                            kind: edit.kind,
                            opacity: edit.opacity,
                            amplitude: edit.amplitude,
                            turns: edit.turns,
                            phase: edit.phase,
                            fadeEdge: edit.fadeEdge,
                            grow: edit.grow,
                            lineEnd: edit.lineEnd,
                            arrowSize: edit.arrowSize,
                            locked: edit.locked,
                            hidden: edit.hidden,
                            layer: edit.layer,
                            name: edit.name,
                            createdAt: edit.createdAt,
                          );

                          state.replaceElement(
                            updated,
                            keepSelection: true,
                            setTool: TgTool.select,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Готово',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (inEditMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Перетаскивайте цветные точки на поле для изменения формы спирали",
                    style: TextStyle(
                      color: _txt,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Section(
          title: 'Радиус спирали',
          trailing: sel.amplitude.toStringAsFixed(0),
          child: Slider(
            min: 5,
            max: 30,
            value: sel.amplitude.clamp(5, 30),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpiral(amplitude: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Количество витков',
          trailing: sel.turns.toStringAsFixed(1),
          child: Slider(
            min: 5,
            max: 40,
            value: sel.turns.clamp(5, 40),
            divisions: 35,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpiral(turns: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Плавность краев',
          trailing: sel.fadeEdge.toStringAsFixed(2),
          child: Slider(
            min: 0.0,
            max: 0.3,
            value: sel.fadeEdge.clamp(0.0, 0.3),
            divisions: 30,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpiral(fadeEdge: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет',
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedSpiral(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Толщина линии',
          trailing: sel.width.toStringAsFixed(1),
          child: Slider(
            min: 1,
            max: 8,
            value: sel.width.clamp(1, 8),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpiral(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Прозрачность',
          trailing: '${(sel.opacity * 100).round()}%',
          child: Slider(
            min: 0.1,
            max: 1,
            value: sel.opacity.clamp(0.1, 1),
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedSpiral(opacity: v),
          ),
        ),
      ],
    );
  }
}

class _CurveEditor extends StatelessWidget {
  const _CurveEditor({
    required this.state,
    required this.sel,
    required this.colors,
    required this.txt,
    required this.border,
    required this.surface,
    required this.green,
  });

  final TgState state;
  final TgEditableCurve sel;
  final List<Color> colors;
  final Color txt;
  final Color border;
  final Color surface;
  final Color green;

  void _lock(bool v) => state.setLockViewport(v);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _Section(
            title: "Редактирование",
            child: Row(
              children: [
                Expanded(
                  child: _ToggleBtn(
                    text: "Редактировать точки",
                    active: sel.showControlPoints,
                    onTap: () {
                      if (!sel.showControlPoints) {
                        state.editSelectedCurvePoints();
                      }
                    },
                  ),
                ),
                if (sel.showControlPoints) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleBtn(
                      text: "Готово",
                      active: false,
                      onTap: () {
                        state.updateSelectedCurve(showControlPoints: false);
                        state.setTool(TgTool.select);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _Section(
          title: "Тип кривой",
          child: Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  text: "Линия",
                  active: sel.curveType == CurveType.line,
                  onTap: () =>
                      state.updateSelectedCurve(curveType: CurveType.line),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: "Квадрат.",
                  active: sel.curveType == CurveType.quadratic,
                  onTap: () => state.updateSelectedCurve(
                    curveType: CurveType.quadratic,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: "Кубич.",
                  active: sel.curveType == CurveType.cubic,
                  onTap: () =>
                      state.updateSelectedCurve(curveType: CurveType.cubic),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Толщина",
          trailing: "${sel.width.toStringAsFixed(1)}",
          child: Slider(
            value: sel.width.clamp(1.0, 18.0),
            min: 1,
            max: 18,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedCurve(width: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Цвет",
          child: _ColorRow(
            colors: colors,
            active: sel.color,
            onPick: (c) => state.updateSelectedCurve(color: c),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Тип линии",
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillType(
                active: sel.kind == LineKind.normal,
                text: "Обычная",
                onTap: () => state.updateSelectedCurve(kind: LineKind.normal),
                green: green,
              ),
              _PillType(
                active: sel.kind == LineKind.dashed,
                text: "Пунктир",
                onTap: () => state.updateSelectedCurve(kind: LineKind.dashed),
                green: green,
              ),
              _PillType(
                active: sel.kind == LineKind.dotted,
                text: "Точечный",
                onTap: () => state.updateSelectedCurve(kind: LineKind.dotted),
                green: green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Прозрачность",
          trailing: "${(sel.opacity * 100).round()}%",
          child: Slider(
            value: sel.opacity.clamp(0.0, 1.0),
            min: 0.1,
            max: 1.0,
            onChangeStart: (_) => _lock(true),
            onChangeEnd: (_) => _lock(false),
            onChanged: (v) => state.updateSelectedCurve(opacity: v),
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Стрелка",
          child: Row(
            children: [
              Expanded(
                child: _ToggleBtn(
                  text: "Нет",
                  active: sel.end == LineEnd.none,
                  onTap: () => state.updateSelectedCurve(end: LineEnd.none),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleBtn(
                  text: "Стрелка",
                  active: sel.end == LineEnd.arrow,
                  onTap: () => state.updateSelectedCurve(end: LineEnd.arrow),
                ),
              ),
            ],
          ),
        ),
        if (sel.end == LineEnd.arrow) ...[
          const SizedBox(height: 10),
          _Section(
            title: "Размер стрелки",
            trailing: "${sel.arrowSize.toStringAsFixed(0)}",
            child: Slider(
              value: sel.arrowSize.clamp(6.0, 44.0),
              min: 6,
              max: 44,
              onChangeStart: (_) => _lock(true),
              onChangeEnd: (_) => _lock(false),
              onChanged: (v) => state.updateSelectedCurve(arrowSize: v),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (sel.showControlPoints)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Перетаскивайте точки на поле для изменения формы кривой",
                    style: TextStyle(
                      color: txt,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== РЕДАКТОРЫ ЦВЕТА ====================
class _PlayerColorEditor extends StatelessWidget {
  const _PlayerColorEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgStamp sel;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final playerColors = sel.playerColors ??
        const PlayerColors(
          jersey: Color(0xFF0068B4),
          shorts: Colors.white,
          skin: Color(0xFFFBCDAA),
          socks: Colors.white,
        );

    return Column(
      children: [
        _Section(
          title: 'Цвет футболки',
          child: _ColorRow(
            colors: [
              const Color(0xFF0068B4),
              const Color(0xFF2F80ED),
              const Color(0xFFEB5757),
              const Color(0xFFF2C94C),
              const Color(0xFF27AE60),
              const Color(0xFF9B51E0),
              Colors.black,
              Colors.white,
              Colors.grey,
            ],
            active: playerColors.jersey,
            onPick: (c) {
              final newColors = playerColors.copyWith(jersey: c);
              state.updateSelectedStamp(playerColors: newColors);
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет трусов',
          child: _ColorRow(
            colors: [
              Colors.white,
              Colors.black,
              const Color(0xFF2F80ED),
              const Color(0xFFEB5757),
              const Color(0xFFF2C94C),
              const Color(0xFF27AE60),
              const Color(0xFF9B51E0),
              Colors.grey,
            ],
            active: playerColors.shorts,
            onPick: (c) {
              final newColors = playerColors.copyWith(shorts: c);
              state.updateSelectedStamp(playerColors: newColors);
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет кожи',
          child: _ColorRow(
            colors: [
              const Color(0xFFFBCDAA),
              const Color(0xFFE0AC69),
              const Color(0xFF8D5524),
              const Color(0xFFC68642),
              const Color(0xFFA0522D),
            ],
            active: playerColors.skin,
            onPick: (c) {
              final newColors = playerColors.copyWith(skin: c);
              state.updateSelectedStamp(playerColors: newColors);
            },
          ),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Цвет гетр',
          child: _ColorRow(
            colors: [
              Colors.white,
              Colors.black,
              const Color(0xFF2F80ED),
              const Color(0xFFEB5757),
              const Color(0xFFF2C94C),
              const Color(0xFF27AE60),
              const Color(0xFF9B51E0),
              Colors.grey,
            ],
            active: playerColors.socks,
            onPick: (c) {
              final newColors = playerColors.copyWith(socks: c);
              state.updateSelectedStamp(playerColors: newColors);
            },
          ),
        ),
      ],
    );
  }
}

class _PropColorEditor extends StatelessWidget {
  const _PropColorEditor({
    required this.state,
    required this.sel,
    required this.colors,
    required this.onRefreshSvg,
  });

  final TgState state;
  final TgStamp sel;
  final List<Color> colors;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;

  static const _green = Color(0xFF00A750);

  @override
  Widget build(BuildContext context) {
    final playerColors = sel.playerColors ??
        const PlayerColors(
          jersey: Color(0xFF0068B4),
          shorts: Colors.white,
          skin: Color(0xFFFBCDAA),
          socks: Colors.white,
          isProp: true,
        );

    return Column(
      children: [
        _Section(
          title: 'Цвет инвентаря',
          child: _ColorRow(
            colors: [
              const Color(0xFF0068B4),
              const Color(0xFF2F80ED),
              const Color(0xFFEB5757),
              const Color(0xFFF2C94C),
              const Color(0xFF27AE60),
              const Color(0xFF9B51E0),
              const Color(0xFFFFA500),
              const Color(0xFFFF69B4),
              const Color(0xFF8B4513),
              Colors.black,
              Colors.white,
              Colors.grey,
            ],
            active: playerColors.jersey,
            onPick: (c) {
              final newColors = playerColors.copyWith(jersey: c, isProp: true);
              state.updateSelectedStamp(playerColors: newColors);
              if (onRefreshSvg != null) {
                onRefreshSvg!(sel.asset, newColors);
              }
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _green.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: playerColors.jersey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Выбранный цвет',
                  style: TextStyle(
                    color: playerColors.jersey.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalColorEditor extends StatelessWidget {
  const _GoalColorEditor({
    required this.state,
    required this.sel,
    required this.colors,
  });

  final TgState state;
  final TgStamp sel;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final playerColors = sel.playerColors ??
        const PlayerColors(
          jersey: Color(0xFF0068B4),
          shorts: Colors.white,
          skin: Color(0xFFFBCDAA),
          socks: Colors.white,
        );

    return Column(
      children: [
        _Section(
          title: 'Цвет ворот',
          child: _ColorRow(
            colors: [
              const Color(0xFF0068B4),
              const Color(0xFF2F80ED),
              const Color(0xFFEB5757),
              const Color(0xFFF2C94C),
              const Color(0xFF27AE60),
              const Color(0xFF9B51E0),
              Colors.black,
              Colors.white,
            ],
            active: playerColors.jersey,
            onPick: (c) {
              final newColors = playerColors.copyWith(jersey: c);
              state.updateSelectedStamp(playerColors: newColors);
            },
          ),
        ),
      ],
    );
  }
}

// Вспомогательный класс для категорий
class CategoryInfo {
  final String name;
  final String path;

  const CategoryInfo({
    required this.name,
    required this.path,
  });
}

// ==================== ОСНОВНАЯ ПАНЕЛЬ ====================
enum TgPanel { none, objects, editor, threeD }

class TgRightPanel extends StatefulWidget {
  const TgRightPanel({
    super.key,
    required this.state,
    required this.stamps,
    this.onRefreshSvg,
    required this.canvasKey,
  });

  final TgState state;
  final List<String> stamps;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;
  final GlobalKey<TgCanvasState> canvasKey;

  @override
  State<TgRightPanel> createState() => _TgRightPanelState();
}

class _TgRightPanelState extends State<TgRightPanel> {
  TgPanel _activePanel = TgPanel.none;

  bool get _panelOpen => _activePanel != TgPanel.none;
  bool get _is3DActive => _activePanel == TgPanel.threeD;
  bool get _isObjectActive => _activePanel == TgPanel.objects;
  bool get _isEditActive => _activePanel == TgPanel.editor;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (widget.state.selected != null &&
        _activePanel != TgPanel.threeD &&
        _activePanel != TgPanel.editor) {
      setState(() {
        _activePanel = TgPanel.editor;
      });
    }
  }

  void _closeAllPanels() {
    setState(() {
      _activePanel = TgPanel.none;
    });
  }

  void _openObjectPanel() {
    setState(() {
      if (_activePanel == TgPanel.objects) {
        _activePanel = TgPanel.none;
        if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      } else {
        _activePanel = TgPanel.objects;
        if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      }
    });
  }

  void _openEditorPanel() {
    if (widget.state.selected == null) return;
    setState(() {
      if (_activePanel == TgPanel.editor) {
        _activePanel = TgPanel.none;
        if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      } else {
        _activePanel = TgPanel.editor;
        if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      }
    });
  }

  void _open3DPanel() {
    setState(() {
      if (_activePanel == TgPanel.threeD) {
        _activePanel = TgPanel.none;
        if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      } else {
        _activePanel = TgPanel.threeD;
        if (!widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      }
    });
  }

  EdgeInsets _panelInsets(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;
    return EdgeInsets.only(top: top + 12, bottom: bottom + 12);
  }

  @override
  Widget build(BuildContext context) {
    final safe = _panelInsets(context);

    return Stack(
      children: [
        _QuickActionCircles(
          state: widget.state,
          onObjectSelected: _openObjectPanel,
          onEditSelected: _openEditorPanel,
          on3DSelected: _open3DPanel,
          showEdit: _isEditActive,
          is3DActive: _is3DActive,
          isObjectActive: _isObjectActive,
          isEditActive: _isEditActive,
        ),
        if (_panelOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeAllPanels,
              child: Container(color: Colors.transparent),
            ),
          ),
        if (_activePanel == TgPanel.objects)
          Positioned(
            right: 88,
            top: safe.top,
            bottom: safe.bottom,
            child: _ObjectPanel(
              state: widget.state,
              stamps: widget.stamps,
              onObjectSelected: (asset) {
                widget.state.setActiveStamp(asset);
                _closeAllPanels();
              },
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.editor && widget.state.selected != null)
          Positioned(
            right: 88,
            top: safe.top,
            bottom: safe.bottom,
            child: _EditorPanel(
              state: widget.state,
              onRefreshSvg: widget.onRefreshSvg,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.threeD)
          Positioned(
            right: 88,
            top: safe.top,
            bottom: safe.bottom,
            child: _ThreeDPanel(
              state: widget.state,
              canvasKey: widget.canvasKey,
              onClose: _closeAllPanels,
            ),
          ),
      ],
    );
  }
}