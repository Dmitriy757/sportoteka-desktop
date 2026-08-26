import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

import '../training_graphics_state.dart';

/// CMR-панель Training Graphics в том же формате, что sidebar карты Tracker.
/// На desktop/tablet использует те же рабочие ширины: 232/262/286/306 px.
class TgLeftToolbar extends StatelessWidget {
  const TgLeftToolbar({
    super.key,
    required this.state,
    required this.workspaceWidth,
    required this.teamName,
    required this.onZoomToSelection,
    required this.onResetView,
    required this.onCloseEditor,
    required this.onOpenObjects,
    required this.onOpenLayers,
    required this.onOpenProperties,
    required this.onOpenTactics,
    required this.onOpenAnimation,
    required this.animationOpen,
    required this.onSet3D,
    required this.onPickFieldTexture,
    required this.onClearFieldTexture,
  });

  final TgState state;
  final double workspaceWidth;
  final String teamName;
  final VoidCallback onZoomToSelection;
  final VoidCallback onResetView;
  final VoidCallback onCloseEditor;
  final VoidCallback onOpenObjects;
  final VoidCallback onOpenLayers;
  final VoidCallback onOpenProperties;
  final VoidCallback onOpenTactics;
  final VoidCallback onOpenAnimation;
  final bool animationOpen;
  final ValueChanged<bool> onSet3D;
  final VoidCallback onPickFieldTexture;
  final VoidCallback onClearFieldTexture;

  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFEFFBF5);
  static const _text = Color(0xFF18231D);
  static const _muted = Color(0xFF738078);
  static const _muted2 = Color(0xFF96A19A);
  static const _soft = Color(0xFFF6F8F7);
  static const _line = Color(0xFFE8ECE9);
  static const _danger = Color(0xFFD9465F);

  double get _width {
    if (workspaceWidth >= 1700) return 306;
    if (workspaceWidth >= 1440) return 286;
    if (workspaceWidth >= 1180) return 262;
    if (workspaceWidth >= 920) return 232;
    return 76;
  }

  bool get _compact => _width < 200;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return SizedBox(
          width: _width,
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(_compact ? 6 : 10, 10, _compact ? 6 : 10, 12),
                    children: [
                      if (!_compact) _section('РИСОВАНИЕ'),
                      _item(
                        icon: Icons.ads_click_rounded,
                        label: 'Выбор',
                        subtitle: 'выделение и трансформация объектов',
                        active: state.tool == TgTool.select,
                        onTap: () => state.setTool(TgTool.select),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.widgets_outlined,
                        label: 'Объекты',
                        subtitle: 'игроки, мячи, фишки и инвентарь',
                        active: state.tool == TgTool.stamp,
                        onTap: onOpenObjects,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.horizontal_rule_rounded,
                        label: 'Линия',
                        subtitle: 'линии, стрелки и направления',
                        active: state.tool == TgTool.line,
                        onTap: () => state.setTool(TgTool.line),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.crop_square_rounded,
                        label: 'Квадрат',
                        subtitle: 'зона или прямоугольная область',
                        active: state.tool == TgTool.rect,
                        onTap: () => state.setTool(TgTool.rect),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.circle_outlined,
                        label: 'Круг',
                        subtitle: 'круглая зона и акцент',
                        active: state.tool == TgTool.circle,
                        onTap: () => state.setTool(TgTool.circle),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.text_fields_rounded,
                        label: 'Текст',
                        subtitle: 'подпись и заметка тренера',
                        active: state.tool == TgTool.text,
                        onTap: () => state.setTool(TgTool.text),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.draw_outlined,
                        label: 'Кривая',
                        subtitle: 'свободная траектория движения',
                        active: state.tool == TgTool.curve,
                        onTap: () => state.setTool(TgTool.curve),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.timeline_rounded,
                        label: 'Волна',
                        subtitle: 'волнистая траектория упражнения',
                        active: state.tool == TgTool.wavy,
                        onTap: () => state.setTool(TgTool.wavy),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.route_rounded,
                        label: 'Серия',
                        subtitle: 'ставить элементы подряд без перевыбора',
                        active: state.continuousDrawMode,
                        onTap: state.toggleContinuousDrawMode,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.auto_awesome_motion_rounded,
                        label: 'Тактика',
                        subtitle: 'расширенные траектории и упражнения',
                        onTap: onOpenTactics,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Анимация',
                        subtitle: 'шаги, маршруты и воспроизведение',
                        active: animationOpen,
                        onTap: onOpenAnimation,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.layers_outlined,
                        label: 'Слои',
                        subtitle: 'порядок и видимость элементов',
                        onTap: onOpenLayers,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.tune_rounded,
                        label: 'Свойства',
                        subtitle: state.selected == null
                            ? 'сначала выберите объект'
                            : 'цвет, толщина, размер и стиль',
                        active: state.selected != null,
                        onTap: state.selected == null ? null : onOpenProperties,
                      ),
                      if (!_compact) ...[
                        const SizedBox(height: 8),
                        _section('ПОЛЕ И КАМЕРА'),
                      ],
                      _item(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Стандартное поле',
                        subtitle: 'фирменная подложка Training Graphics',
                        active: !state.hasCustomFieldTexture,
                        onTap: onClearFieldTexture,
                      ),
                      _gap(),
                      _item(
                        icon: Icons.image_outlined,
                        label: 'Своя текстура',
                        subtitle: state.hasCustomFieldTexture
                            ? (state.customFieldTextureName ?? 'пользовательская подложка')
                            : 'PNG / JPG / WEBP поверх поля',
                        active: state.hasCustomFieldTexture,
                        onTap: onPickFieldTexture,
                      ),
                      if (!_compact && state.hasCustomFieldTexture) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 2, 8, 5),
                          child: Row(
                            children: [
                              const Text(
                                'Наложение',
                                style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w600, color: _muted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    activeTrackColor: _green,
                                    inactiveTrackColor: _line,
                                    thumbColor: _green,
                                    overlayColor: _greenSoft,
                                  ),
                                  child: Slider(
                                    value: state.customFieldTextureOpacity,
                                    min: 0.10,
                                    max: 1.0,
                                    onChanged: state.setCustomFieldTextureOpacity,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${(state.customFieldTextureOpacity * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700, color: _muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _gap(),
                      _item(
                        icon: Icons.grid_4x4_rounded,
                        label: 'Сетка',
                        subtitle: 'сетка позиционирования объектов',
                        active: state.gridEnabled,
                        onTap: state.toggleGrid,
                      ),
                      _gap(),
                      _item(
                        icon: state.lockViewportGestures
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        label: 'Камера',
                        subtitle: state.lockViewportGestures
                            ? 'перемещение и масштаб заблокированы'
                            : 'перемещение и масштаб разрешены',
                        active: state.lockViewportGestures,
                        onTap: () => state.setLockViewport(!state.lockViewportGestures),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.view_in_ar_rounded,
                        label: '3D PRO',
                        subtitle: 'перспектива и джойстик камеры',
                        active: state.is3DMode,
                        onTap: () => onSet3D(true),
                      ),
                      _gap(),
                      _item(
                        icon: Icons.crop_landscape_rounded,
                        label: '2D',
                        subtitle: 'плоский вид поля',
                        active: !state.is3DMode,
                        onTap: () => onSet3D(false),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: _line),
                Padding(
                  padding: EdgeInsets.fromLTRB(_compact ? 6 : 10, 8, _compact ? 6 : 10, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _mini(Icons.undo_rounded, 'Отменить', state.canUndo ? state.undo : null)),
                          const SizedBox(width: 4),
                          Expanded(child: _mini(Icons.redo_rounded, 'Повторить', state.canRedo ? state.redo : null)),
                          const SizedBox(width: 4),
                          Expanded(child: _mini(Icons.center_focus_strong_rounded, 'Вписать', onResetView)),
                          const SizedBox(width: 4),
                          Expanded(child: _mini(Icons.zoom_in_map_rounded, 'К объекту', onZoomToSelection)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      _backItem(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 7),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: _muted2,
          fontSize: AppTypography.badgeSize,
          fontWeight: FontWeight.w700,
          letterSpacing: .45,
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 4);

  Widget _item({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    if (_compact) {
      return Tooltip(
        message: '$label\n$subtitle',
        child: Material(
          color: active ? _greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              height: 46,
              child: Icon(icon, size: 18, color: active ? _green : (onTap == null ? _muted2 : _muted)),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: active ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: active ? _green : (onTap == null ? _muted2 : _muted)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: AppTypography.captionSize,
                        weight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active ? _green : (onTap == null ? _muted2 : _text),
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: AppTypography.captionSize,
                        weight: FontWeight.w400,
                        color: active ? _green.withOpacity(.72) : _muted,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _soft,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 30,
            child: Icon(icon, size: 15, color: onTap == null ? _muted2 : _text),
          ),
        ),
      ),
    );
  }

  Widget _backItem() {
    if (_compact) {
      return Tooltip(
        message: 'К меню тренировок',
        child: Material(
          color: _soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onCloseEditor,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              height: 46,
              child: Icon(Icons.arrow_back_rounded, size: 18, color: _text),
            ),
          ),
        ),
      );
    }

    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onCloseEditor,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'К меню тренировок',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: AppTypography.captionSize,
                        weight: FontWeight.w600,
                        color: _text,
                        height: 1.18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      teamName.isEmpty ? 'Training Graphics' : '$teamName · Training Graphics',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.custom(
                        size: AppTypography.badgeSize,
                        weight: FontWeight.w500,
                        color: _muted2,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.arrow_back_rounded, size: 16, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
