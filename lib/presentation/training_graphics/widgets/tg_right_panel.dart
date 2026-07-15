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


String _defaultPlayerStamp(List<String> stamps, Map<String, dynamic> player) {
  final pos = '${player['position'] ?? player['role'] ?? player['amplua'] ?? player['player_position'] ?? ''}'.toLowerCase();

  String preferred = '';
  if (pos.contains('вр') || pos.contains('врат') || pos.contains('gk') || pos.contains('goal')) {
    preferred = stamps.firstWhere(
      (e) => e.contains('/vrat_svg/') || e.toLowerCase().contains('goalkeeper'),
      orElse: () => '',
    );
  }

  if (preferred.isEmpty) {
    preferred = stamps.firstWhere(
      (e) => e.contains('/stand_svg/front_left') || e.contains('/player_m/stand') || e.contains('/player_m/'),
      orElse: () => '',
    );
  }

  return preferred.isNotEmpty ? preferred : (stamps.isNotEmpty ? stamps.first : '');
}

String _playerName(Map<String, dynamic> p) {
  final full = (p['full_name'] ??
          p['fullName'] ??
          p['player_name'] ??
          p['playerName'] ??
          p['fio'] ??
          p['name'] ??
          '')
      .toString()
      .trim();

  if (full.isNotEmpty) return full;

  final last = (p['last_name'] ?? p['lastName'] ?? p['surname'] ?? '').toString().trim();
  final first = (p['first_name'] ?? p['firstName'] ?? '').toString().trim();
  final joined = [last, first].where((e) => e.isNotEmpty).join(' ').trim();

  return joined.isNotEmpty ? joined : 'Игрок';
}

int _playerNumber(Map<String, dynamic> p) {
  final v = p['number'] ??
      p['player_number'] ??
      p['playerNumber'] ??
      p['shirt_number'] ??
      p['shirtNumber'] ??
      p['jersey_number'] ??
      p['jersey'];

  if (v is int) return v;
  if (v is num) return v.toInt();

  return int.tryParse((v ?? '').toString().replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
}

String _playerPosition(Map<String, dynamic> p) {
  return (p['position'] ??
          p['role'] ??
          p['amplua'] ??
          p['player_position'] ??
          p['playerPosition'] ??
          p['position_name'] ??
          'Игрок')
      .toString()
      .trim();
}

String _playerAvatar(Map<String, dynamic> p) {
  final raw = (p['photo'] ??
          p['photo_url'] ??
          p['photoUrl'] ??
          p['avatar'] ??
          p['avatar_url'] ??
          p['avatarUrl'] ??
          p['image'] ??
          p['image_url'] ??
          p['imageUrl'] ??
          '')
      .toString()
      .trim();

  if (raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';

  return 'https://sportotekaapp.ru/$raw';
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
  final VoidCallback onTemplatesSelected;
  final VoidCallback onLayersSelected;
  final VoidCallback on3DObjectsSelected;
  final VoidCallback onExportSelected;
  final VoidCallback onEditSelected;
  final VoidCallback on3DSelected;
  final bool isObjectActive;
  final bool isTemplatesActive;
  final bool isLayersActive;
  final bool is3DObjectsActive;
  final bool isExportActive;
  final bool isEditActive;
  final bool is3DActive;

  const _QuickActionCircles({
    required this.state,
    required this.onObjectSelected,
    required this.onTemplatesSelected,
    required this.onLayersSelected,
    required this.on3DObjectsSelected,
    required this.onExportSelected,
    required this.onEditSelected,
    required this.on3DSelected,
    required this.isObjectActive,
    required this.isTemplatesActive,
    required this.isLayersActive,
    required this.is3DObjectsActive,
    required this.isExportActive,
    required this.isEditActive,
    required this.is3DActive,
  });

  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFF3FBF7);
  static const _panel = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFFAFBFC);
  static const _border = Color(0xFFF0F2F4);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 1280 || MediaQuery.of(context).size.height < 820;
    final dockWidth = compact ? 54.0 : 62.0;
    final radius = compact ? 16.0 : 20.0;
    return Positioned(
      right: compact ? 8 : 12,
      top: compact ? 10 : 16,
      child: Container(
        width: dockWidth,
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 26,
              spreadRadius: -14,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDockButton(
              context: context,
              icon: Icons.dashboard_customize,
              label: 'Шаблоны',
              isActive: isTemplatesActive,
              onTap: onTemplatesSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.category,
              label: 'Объекты',
              isActive: isObjectActive,
              onTap: onObjectSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.layers,
              label: 'Слои',
              isActive: isLayersActive,
              onTap: onLayersSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.view_in_ar_rounded,
              label: '3D объекты',
              isActive: is3DObjectsActive,
              onTap: on3DObjectsSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.tune,
              label: 'Свойства',
              isActive: isEditActive,
              enabled: state.selected != null,
              onTap: state.selected == null ? null : onEditSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.view_in_ar,
              label: 'Камера',
              isActive: is3DActive,
              onTap: on3DSelected,
            ),
            const SizedBox(height: 6),
            _buildDockButton(
              context: context,
              icon: Icons.file_download,
              label: 'Экспорт',
              isActive: isExportActive,
              onTap: onExportSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final mq = MediaQuery.of(context).size;
    final compact = mq.width < 1280 || mq.height < 820;
    final buttonW = compact ? 40.0 : 46.0;
    final buttonH = compact ? 38.0 : 42.0;
    final color = !enabled ? _muted.withOpacity(.35) : (isActive ? _green : _muted);
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Material(
          color: isActive ? _greenSoft : _surface,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: buttonW,
              height: buttonH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isActive ? _green.withOpacity(.25) : _border),
              ),
              child: Stack(
                children: [
                  if (isActive)
                    Positioned(
                      left: 4,
                      top: 12,
                      bottom: 12,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Center(child: Icon(icon, size: 19, color: color)),
                ],
              ),
            ),
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
  static const _panel = Color(0xFFFFFFFF);
  static const _surface = Color(0xFFFAFBFC);
  static const _border = Color(0xFFF0F2F4);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 38,
            spreadRadius: -18,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width < 900 ? 10 : 14,
                MediaQuery.of(context).size.width < 900 ? 9 : 12,
                MediaQuery.of(context).size.width < 900 ? 10 : 14,
                16,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 250;
        return Container(
      height: narrow ? 50 : 58,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: narrow ? 30 : 34,
            height: narrow ? 30 : 34,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, size: narrow ? 15 : 17, color: _text),
          ),
          SizedBox(width: narrow ? 7 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'панель редактора',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          _PanelCloseButton(onTap: onClose),
        ],
      ),
    );
      },
    );
  }
}


class _PanelCloseButton extends StatelessWidget {
  const _PanelCloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = MediaQuery.of(context).size.width < 900 || c.maxWidth < 90;
        return Tooltip(
      message: 'Закрыть панель',
      child: Material(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: narrow ? 32 : 34,
            padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE11D48)),
                if (!narrow) ...const [
                  SizedBox(width: 4),
                  Text(
                  'Закрыть',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}

// ==================== ПАНЕЛЬ ОБЪЕКТОВ ====================
class _ObjectPanel extends _BasePanel {
  final TgState state;
  final List<String> stamps;
  final ValueChanged<String> onObjectSelected;
  final ValueChanged<Map<String, dynamic>> onPlayerSelected;
  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;
  final bool teamPlayersLoading;
  final String? teamPlayersError;
  final VoidCallback? onOpen3DPro;

  _ObjectPanel({
    required this.state,
    required this.stamps,
    required this.onObjectSelected,
    required this.onPlayerSelected,
    required this.teamName,
    required this.teamPlayers,
    required this.teamPlayersLoading,
    required this.teamPlayersError,
    required this.onOpen3DPro,
    required super.onClose,
  }) : super(
          title: 'Объекты',
          icon: Icons.category,
          child: _ObjectPanelContent(
            state: state,
            stamps: stamps,
            onObjectSelected: onObjectSelected,
            onPlayerSelected: onPlayerSelected,
            teamName: teamName,
            teamPlayers: teamPlayers,
            teamPlayersLoading: teamPlayersLoading,
            teamPlayersError: teamPlayersError,
            onOpen3DPro: onOpen3DPro,
          ),
        );
}

class _ObjectPanelContent extends StatefulWidget {
  final TgState state;
  final List<String> stamps;
  final ValueChanged<String> onObjectSelected;
  final ValueChanged<Map<String, dynamic>> onPlayerSelected;
  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;
  final bool teamPlayersLoading;
  final String? teamPlayersError;
  final VoidCallback? onOpen3DPro;

  const _ObjectPanelContent({
    required this.state,
    required this.stamps,
    required this.onObjectSelected,
    required this.onPlayerSelected,
    required this.teamName,
    required this.teamPlayers,
    required this.teamPlayersLoading,
    required this.teamPlayersError,
    required this.onOpen3DPro,
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
  static const _greenSoft = Color(0xFFF3FBF7);

  final List<CategoryInfo> categories = const [
    CategoryInfo(name: 'Игроки · мужчины', path: '/player_m/'),
    CategoryInfo(name: 'Игроки · женщины', path: '/player_f/'),
    CategoryInfo(name: 'Тренеры', path: '/coach/'),
    CategoryInfo(name: 'Инвентарь', path: '/props/'),
    CategoryInfo(name: 'Беговые действия', path: '/run_svg/'),
    CategoryInfo(name: 'Пас / передача', path: '/pass_svg/'),
    CategoryInfo(name: 'Статика / позиция', path: '/stand_svg/'),
    CategoryInfo(name: 'Прыжок', path: '/jump_svg/'),
    CategoryInfo(name: 'Вратарь', path: '/vrat_svg/'),
    CategoryInfo(name: 'Ворота', path: '/vorota1/'),
  ];

  int _selectedCategoryIndex = 0;

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Тактические схемы',
          trailing: 'TacticalPad',
          child: Column(
            children: [
              _tacticalPresetRow([
                _TacticalPreset('4-3-3', 'расстановка', Icons.grid_view_rounded, '433'),
                _TacticalPreset('4-4-2', 'расстановка', Icons.grid_view_rounded, '442'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('3-5-2', 'расстановка', Icons.grid_view_rounded, '352'),
                _TacticalPreset('4-2-3-1', 'расстановка', Icons.grid_view_rounded, '4231'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('5-3-2', 'расстановка', Icons.grid_view_rounded, '532'),
                _TacticalPreset('Билдап', 'выход из обороны', Icons.account_tree_rounded, 'build_up'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('От ворот', 'розыгрыш GK', Icons.sports_soccer_rounded, 'goal_kick'),
                _TacticalPreset('Контратака', 'быстрый выход', Icons.flash_on_rounded, 'counter'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('Прессинг', 'зона давления', Icons.radar_rounded, 'pressing'),
                _TacticalPreset('Низкий блок', '5-4-1', Icons.shield_outlined, 'low_block'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('Рондо', '5v2', Icons.radio_button_checked_rounded, 'rondo'),
                _TacticalPreset('Скорость', 'станции', Icons.speed_rounded, 'speed'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('Офсайд', 'линия защиты', Icons.align_vertical_center_rounded, 'offside'),
                _TacticalPreset('Забегание', 'overlap', Icons.trending_up_rounded, 'overlap'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('3-й игрок', 'комбинация', Icons.hub_rounded, 'third_man'),
                _TacticalPreset('Угловой', 'стандарт', Icons.flag_rounded, 'corner'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('Штрафной', 'стандарт', Icons.sports_rounded, 'free_kick'),
                _TacticalPreset('Атака 1–4', 'шаги/кадры', Icons.play_circle_outline_rounded, 'animation_attack'),
              ], context),
              const SizedBox(height: 8),
              _tacticalPresetRow([
                _TacticalPreset('Полный пакет', 'всё сразу', Icons.auto_awesome_rounded, 'full_pack'),
                _TacticalPreset('Пусто', 'очистить tactical', Icons.cleaning_services_rounded, 'clear_tactical'),
              ], context),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTeamPlayersSection(),
        const SizedBox(height: 12),
        _buildBroadcastPresets(),
        const SizedBox(height: 12),
        _buildCategoryDropdown(items.length),
        const SizedBox(height: 10),
        if (items.isEmpty) _buildEmptyState() else _buildObjectList(items),
        const SizedBox(height: 12),
        _buildInfo(),
      ],
    );
  }


  Widget _tacticalPresetRow(List<_TacticalPreset> items, BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tacticalPresetCard(items[0], context)),
        const SizedBox(width: 8),
        Expanded(child: _tacticalPresetCard(items[1], context)),
      ],
    );
  }

  Widget _tacticalPresetCard(_TacticalPreset t, BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          widget.state.applyTacticalPreset(t.key);
          _showObjectHint(
            context,
            t.key == 'clear_tactical'
                ? 'Тактический слой очищен.'
                : 'Добавлен TacticalPad пресет «${t.title}». Откройте «Слои» или «Свойства» для редактирования.',
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(t.icon, size: 17, color: _green),
              ),
              const SizedBox(height: 8),
              Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                t.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _txtDim, fontSize: 10, height: 1.2, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showObjectHint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Widget _buildTeamPlayersSection() {
    final players = widget.teamPlayers;

    return _Section(
      title: widget.teamName.trim().isEmpty ? 'Состав команды' : widget.teamName,
      trailing: widget.teamPlayersLoading ? 'загрузка' : '${players.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.teamPlayersLoading)
            _playersLoading()
          else if (players.isEmpty)
            _playersEmpty()
          else
            ...players.take(14).map(_playerCard).toList(),
          if (widget.onOpen3DPro != null) ...[
            const SizedBox(height: 8),
            Material(
              color: _txt,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: widget.onOpen3DPro,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Открыть 3D Pro с этим составом',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playersLoading() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Загружаю игроков команды...',
              style: TextStyle(color: _txtDim, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playersEmpty() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Text(
        widget.teamPlayersError?.trim().isNotEmpty == true
            ? 'Игроки не загрузились: ${widget.teamPlayersError}'
            : 'Игроки команды пока не загружены. Открой редактор из команды или проверь team_id.',
        style: const TextStyle(color: _txtDim, fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final name = _playerName(player);
    final number = _playerNumber(player);
    final pos = _playerPosition(player);
    final avatar = _playerAvatar(player);
    final asset = _defaultPlayerStamp(widget.stamps, player);
    final active = widget.state.activeStampAsset == asset && widget.state.tool == TgTool.stamp;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? _greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => widget.onPlayerSelected(player),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _green : _border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _border),
                  ),
                  child: avatar.isEmpty
                      ? Center(
                          child: Text(
                            number > 0 ? '$number' : _initials(name),
                            style: const TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        )
                      : Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              number > 0 ? '$number' : _initials(name),
                              style: const TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number > 0 ? '№$number  $name' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _green : _txt,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pos.isEmpty ? 'Игрок команды' : pos,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _txtDim,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: active ? _green : _txtDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.length == 1 && parts.first.length >= 2) return parts.first.substring(0, 2).toUpperCase();
    return 'ИГ';
  }

  Widget _buildBroadcastPresets() {
    return _Section(
      title: 'FIFA / TV графика',
      trailing: 'пресеты',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _presetCard(
                  icon: Icons.arrow_forward_rounded,
                  title: 'Атака',
                  subtitle: 'стрелка / рывок',
                  onTap: () => widget.state.setTool(TgTool.line),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _presetCard(
                  icon: Icons.timeline_rounded,
                  title: 'Маршрут',
                  subtitle: 'волна / дриблинг',
                  onTap: () => widget.state.setTool(TgTool.wavy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _presetCard(
                  icon: Icons.grid_view_rounded,
                  title: 'Зона',
                  subtitle: 'блок / зона',
                  onTap: () => widget.state.setTool(TgTool.rect),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _presetCard(
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Эпизод',
                  subtitle: 'акцент / круг',
                  onTap: () => widget.state.setTool(TgTool.circle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _presetCard(
                  icon: Icons.text_fields_rounded,
                  title: 'Подпись',
                  subtitle: 'номер / роль',
                  onTap: () => widget.state.setTool(TgTool.text),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _presetCard(
                  icon: Icons.view_in_ar_rounded,
                  title: '3D поле',
                  subtitle: 'трансляция',
                  onTap: () {
                    if (!widget.state.is3DMode) widget.state.toggle3DMode();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: _green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _txt,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _txtDim,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
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

  Widget _buildCategoryDropdown(int count) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_rounded, color: _green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCategoryIndex,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _txtDim),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                style: const TextStyle(
                  color: _txt,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                items: List.generate(categories.length, (index) {
                  final c = categories[index];
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        Icon(_categoryIcon(c.path), size: 16, color: _txtDim),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCategoryIndex = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _green,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectList(List<String> items) {
    return Column(
      children: items.map(_buildObjectRow).toList(),
    );
  }

  Widget _buildObjectRow(String asset) {
    final active = widget.state.activeStampAsset == asset &&
        widget.state.tool == TgTool.stamp;
    final category = categories[_selectedCategoryIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? _greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => widget.onObjectSelected(asset),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _green : _border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: _stampThumb(asset),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _assetTitle(asset),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? _green : _txt,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _txtDim,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: active ? _green : _txtDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String path) {
    if (path.contains('coach')) return Icons.sports_rounded;
    if (path.contains('props')) return Icons.construction_rounded;
    if (path.contains('run')) return Icons.directions_run_rounded;
    if (path.contains('pass')) return Icons.trending_flat_rounded;
    if (path.contains('stand')) return Icons.accessibility_new_rounded;
    if (path.contains('jump')) return Icons.keyboard_arrow_up_rounded;
    if (path.contains('vrat')) return Icons.sports_soccer_rounded;
    if (path.contains('vorota')) return Icons.crop_16_9_rounded;
    return Icons.person_rounded;
  }

  String _assetTitle(String asset) {
    final file = asset.split('/').where((p) => p.trim().isNotEmpty).last;
    final raw = file
        .replaceAll('.svg', '')
        .replaceAll('.png', '')
        .replaceAll('.jpg', '')
        .replaceAll('.jpeg', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    if (raw.trim().isEmpty) return 'Объект';
    return raw
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.length <= 1 ? p.toUpperCase() : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: _txtDim, size: 24),
          SizedBox(height: 8),
          Text(
            'В этой категории пока нет объектов',
            textAlign: TextAlign.center,
            style: TextStyle(color: _txtDim, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: _green),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Выберите элемент из списка вниз, затем нажмите на поле. Для ТВ-графики сначала выберите пресет.',
              style: TextStyle(color: _txtDim, fontSize: 10.5, fontWeight: FontWeight.w600),
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
        _buildSceneElementsList(),
        const SizedBox(height: 12),
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

  Widget _buildSceneElementsList() {
    final elements = state.elements;
    if (elements.isEmpty) return const SizedBox.shrink();

    final selectedId = state.selectedId;
    final safeSelectedId = elements.any((e) => e.id == selectedId)
        ? selectedId
        : elements.last.id;

    return _Section(
      title: 'Элементы на схеме',
      trailing: '${elements.length}',
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: safeSelectedId,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            items: elements.reversed.map((element) {
              return DropdownMenuItem<String>(
                value: element.id,
                child: Row(
                  children: [
                    Icon(_elementIcon(element), size: 16, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _elementTitle(element),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              state.selectById(id);
            },
          ),
        ),
      ),
    );
  }

  IconData _elementIcon(TgElement element) {
    if (element is TgStamp) return Icons.person_rounded;
    if (element is TgLine) return Icons.trending_flat_rounded;
    if (element is TgRect) return Icons.crop_square_rounded;
    if (element is TgCircle) return Icons.circle_outlined;
    if (element is TgText) return Icons.text_fields_rounded;
    if (element is TgWavy || element is TgEditableWavy) return Icons.timeline_rounded;
    if (element is TgZigzag || element is TgEditableZigzag) return Icons.show_chart_rounded;
    if (element is TgSpring || element is TgEditableSpring) return Icons.all_inclusive_rounded;
    if (element is TgSpiral || element is TgEditableSpiral) return Icons.gesture_rounded;
    return Icons.layers_rounded;
  }

  String _elementTitle(TgElement element) {
    final custom = element.name?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    String type;
    if (element is TgStamp) type = 'Игрок / объект';
    else if (element is TgLine) type = 'Линия / стрелка';
    else if (element is TgRect) type = 'Зона';
    else if (element is TgCircle) type = 'Акцент / круг';
    else if (element is TgText) type = 'Текст';
    else if (element is TgWavy || element is TgEditableWavy) type = 'Маршрут / волна';
    else if (element is TgZigzag || element is TgEditableZigzag) type = 'Зигзаг';
    else if (element is TgSpring || element is TgEditableSpring) type = 'Пружина';
    else if (element is TgSpiral || element is TgEditableSpiral) type = 'Спираль';
    else type = 'Элемент';

    final shortId = element.id.length > 5 ? element.id.substring(element.id.length - 5) : element.id;
    return '$type · $shortId';
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
          title: '3D камера',
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
        _buildCameraPresets(),
        const SizedBox(height: 16),
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

  Widget _buildCameraPresets() {
    return _Section(
      title: 'FIFA камера',
      trailing: 'presets',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _cameraPreset('TV', Icons.live_tv, -0.78, 0.0)),
              const SizedBox(width: 8),
              Expanded(child: _cameraPreset('Тактика', Icons.map, -1.18, 0.0)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _cameraPreset('Диагональ', Icons.threed_rotation, -0.92, -0.36)),
              const SizedBox(width: 8),
              Expanded(child: _cameraPreset('Сверху', Icons.grid_on, -1.55, 0.0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cameraPreset(String title, IconData icon, double rx, double rz) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          canvasKey.currentState?.setRotationX(rx);
          canvasKey.currentState?.setRotationZ(rz);
          canvasKey.currentState?.centerView();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _green),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _txt,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

// ==================== ПРОФЕССИОНАЛЬНЫЕ FIFA/TV ПАНЕЛИ ====================
class _TemplatesPanel extends _BasePanel {
  final TgState state;

  _TemplatesPanel({
    required this.state,
    required super.onClose,
  }) : super(
          title: 'Шаблоны эфира',
          icon: Icons.dashboard_customize,
          child: _TemplatesPanelContent(state: state),
        );
}

class _TemplatesPanelContent extends StatelessWidget {
  const _TemplatesPanelContent({required this.state});
  final TgState state;

  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFF3FBF7);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'FIFA / Broadcast пресеты',
          trailing: 'быстрый старт',
          child: Column(
            children: [
              _templateRow([
                _BroadcastTemplate('Гол', 'титр + акцент игрока', Icons.sports_soccer, TgTool.text),
                _BroadcastTemplate('Замена', 'номер / игрок / минута', Icons.swap_horiz, TgTool.text),
              ], context),
              const SizedBox(height: 8),
              _templateRow([
                _BroadcastTemplate('Опасная атака', 'стрелка + зона', Icons.local_fire_department, TgTool.line),
                _BroadcastTemplate('Прессинг', 'зона давления', Icons.radar, TgTool.circle),
              ], context),
              const SizedBox(height: 8),
              _templateRow([
                _BroadcastTemplate('Тепловая зона', 'полупрозрачный круг', Icons.blur_circular, TgTool.circle),
                _BroadcastTemplate('Передача', 'линия паса', Icons.trending_flat, TgTool.line),
              ], context),
              const SizedBox(height: 8),
              _templateRow([
                _BroadcastTemplate('Рывок', 'стрелка движения', Icons.directions_run, TgTool.line),
                _BroadcastTemplate('Дриблинг', 'волнистый маршрут', Icons.timeline, TgTool.wavy),
              ], context),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Пакеты оформления',
          trailing: 'стиль',
          child: Column(
            children: [
              _stylePreset(
                icon: Icons.live_tv,
                title: 'TV Replay',
                subtitle: 'минимум лишнего, крупные акценты, чистые подписи',
              ),
              const SizedBox(height: 8),
              _stylePreset(
                icon: Icons.analytics,
                title: 'Tactical Board',
                subtitle: 'строгая тактика: зоны, линии, маршруты и номера',
              ),
              const SizedBox(height: 8),
              _stylePreset(
                icon: Icons.view_in_ar,
                title: '3D Match View',
                subtitle: 'вид как в трансляции: камера, перспектива, глубина',
                onTap: () {
                  if (!state.is3DMode) state.toggle3DMode();
                  _hint(context, 'Включён 3D-вид поля. Камеру настройте в панели 3D.');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Как пользоваться',
          child: const Text(
            'Выберите шаблон, затем поставьте элемент на поле. После выбора элемента откройте «Свойства» или «Слои» для точной настройки.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _tacticalPresetRow(List<_TacticalPreset> items, BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tacticalPresetCard(items[0], context)),
        const SizedBox(width: 8),
        Expanded(child: _tacticalPresetCard(items[1], context)),
      ],
    );
  }

  Widget _tacticalPresetCard(_TacticalPreset t, BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          state.applyTacticalPreset(t.key);
          _hint(context, t.key == 'clear_tactical'
              ? 'Тактический слой очищен.'
              : 'Добавлен TacticalPad пресет «${t.title}». Откройте «Слои» или «Свойства» для редактирования.');
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(t.icon, size: 17, color: _green),
              ),
              const SizedBox(height: 8),
              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(t.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, height: 1.2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateRow(List<_BroadcastTemplate> items, BuildContext context) {
    return Row(
      children: [
        Expanded(child: _templateCard(items[0], context)),
        const SizedBox(width: 8),
        Expanded(child: _templateCard(items[1], context)),
      ],
    );
  }

  Widget _templateCard(_BroadcastTemplate t, BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          state.setTool(t.tool);
          _hint(context, 'Шаблон «${t.title}» выбран. Нажмите/проведите на поле, чтобы добавить графику.');
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(t.icon, size: 17, color: _green),
              ),
              const SizedBox(height: 8),
              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(t.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, height: 1.2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stylePreset({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _TacticalPreset {
  final String title;
  final String subtitle;
  final IconData icon;
  final String key;
  const _TacticalPreset(this.title, this.subtitle, this.icon, this.key);
}

class _BroadcastTemplate {
  const _BroadcastTemplate(this.title, this.subtitle, this.icon, this.tool);
  final String title;
  final String subtitle;
  final IconData icon;
  final TgTool tool;
}

class _LayersPanel extends _BasePanel {
  final TgState state;
  final VoidCallback onOpenProperties;

  _LayersPanel({
    required this.state,
    required this.onOpenProperties,
    required super.onClose,
  }) : super(
          title: 'Слои',
          icon: Icons.layers,
          child: _LayersPanelContent(state: state, onOpenProperties: onOpenProperties),
        );
}

class _LayersPanelContent extends StatelessWidget {
  const _LayersPanelContent({required this.state, required this.onOpenProperties});
  final TgState state;
  final VoidCallback onOpenProperties;

  static const _green = Color(0xFF00A750);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final elements = state.elements.reversed.toList();
    if (elements.isEmpty) {
      return _Section(
        title: 'Слои схемы',
        child: const Text('Пока нет объектов. Добавьте игроков, стрелки, зоны или подписи.', style: TextStyle(color: _muted, fontSize: 12)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Слои схемы',
          trailing: '${elements.length}',
          child: Column(
            children: elements.map((e) => _layerTile(context, e)).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Группы слоёв',
          trailing: 'логика',
          child: Column(
            children: [
              for (final layer in state.layerNames)
                _layerGroup(_layerTitle(layer), layer, elements.where((e) => e.layer == layer).length),
            ],
          ),
        ),
      ],
    );
  }

  String _layerTitle(String layer) {
    if (layer == 'default') return 'Основной слой';
    if (layer == 'players') return 'Игроки';
    if (layer == 'actions') return 'Маршруты / передачи';
    if (layer == 'zones') return 'Зоны / акценты';
    if (layer == 'titles') return 'Титры';
    if (layer.startsWith('tactical_')) return 'TacticalPad · ${layer.substring(9)}';
    if (layer == 'tactical') return 'TacticalPad';
    return layer;
  }

  Widget _layerTile(BuildContext context, TgElement e) {
    final selected = state.selectedId == e.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFF3FBF7) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            state.selectLayerItem(e.id);
            onOpenProperties();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? _green : _border, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Icon(_elementIcon(e), size: 17, color: selected ? _green : _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_elementTitle(e), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(e.layer == 'default' ? 'основной слой' : e.layer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _miniIcon(e.hidden ? Icons.visibility_off : Icons.visibility, () => state.updateElementMetaById(e.id, hidden: !e.hidden)),
                _miniIcon(e.locked ? Icons.lock : Icons.lock_open, () => state.updateElementMetaById(e.id, locked: !e.locked)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 18, color: _muted),
                  tooltip: 'Действия слоя',
                  onSelected: (v) {
                    state.selectLayerItem(e.id);
                    if (v == 'front') state.bringToFront();
                    if (v == 'back') state.sendToBack();
                    if (v == 'up') state.moveSelectedForward();
                    if (v == 'down') state.moveSelectedBackward();
                    if (v == 'duplicate') state.duplicateSelected();
                    if (v == 'delete') state.deleteElementById(e.id);
                    if (v == 'rename') _rename(context, e);
                    if (v.startsWith('layer:')) state.updateElementMetaById(e.id, layer: v.substring(6));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                    PopupMenuItem(value: 'front', child: Text('Самый верх')),
                    PopupMenuItem(value: 'back', child: Text('Самый низ')),
                    PopupMenuItem(value: 'up', child: Text('На слой выше')),
                    PopupMenuItem(value: 'down', child: Text('На слой ниже')),
                    PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'layer:players', child: Text('Группа: Игроки')),
                    PopupMenuItem(value: 'layer:actions', child: Text('Группа: Действия')),
                    PopupMenuItem(value: 'layer:zones', child: Text('Группа: Зоны')),
                    PopupMenuItem(value: 'layer:titles', child: Text('Группа: Титры')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: _muted),
      ),
    );
  }

  Widget _layerGroup(String title, String layer, int count) {
    final groupItems = state.elements.where((e) => e.layer == layer).toList();
    final hasItems = groupItems.isNotEmpty;
    final allHidden = hasItems && groupItems.every((e) => e.hidden);
    final allLocked = hasItems && groupItems.every((e) => e.locked);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _txt, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(layer, style: const TextStyle(color: _muted, fontSize: 9.8, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text('$count', style: const TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          _miniIcon(allHidden ? Icons.visibility_off : Icons.visibility, () => state.setLayerGroupHidden(layer, !allHidden)),
          _miniIcon(allLocked ? Icons.lock : Icons.lock_open, () => state.setLayerGroupLocked(layer, !allLocked)),
          _miniIcon(Icons.copy_rounded, () => state.duplicateLayerGroup(layer)),
          _miniIcon(Icons.delete_outline_rounded, () => state.deleteLayerGroup(layer)),
        ],
      ),
    );
  }

  void _toggleMeta(TgElement e, {bool? hidden, bool? locked, String? layer, String? name}) {
    state.updateElementMetaById(e.id, hidden: hidden, locked: locked, layer: layer, name: name);
  }

  Future<void> _rename(BuildContext context, TgElement e) async {
    final c = TextEditingController(text: e.name ?? _elementTitle(e));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Название слоя'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Например: Прессинг 67 мин')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    _toggleMeta(e, name: name);
  }
}


class _ThreeDObjectsPanel extends _BasePanel {
  final TgState state;

  _ThreeDObjectsPanel({
    required this.state,
    required super.onClose,
  }) : super(
          title: '3D объекты',
          icon: Icons.view_in_ar_rounded,
          child: _ThreeDObjectsPanelContent(state: state),
        );
}

class _ThreeDObjectsPanelContent extends StatelessWidget {
  const _ThreeDObjectsPanelContent({required this.state});
  final TgState state;

  static const _green = Color(0xFF00A750);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    final elements = state.elements.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Логика 3D',
          trailing: 'без тайминга',
          child: const Text(
            'Тайминг убран из основного редактора. Здесь настраивается сцена: поле, камера, глубина, 3D-объекты и формат для Unity/GLB.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Формат сцены',
          trailing: 'pipeline',
          child: Column(
            children: [
              _modeTile(context, Icons.layers_rounded, 'Flutter 2.5D', 'быстро: поле с перспективой, тени, глубина объектов'),
              _modeTile(context, Icons.view_in_ar_rounded, 'GLB / glTF сцена', 'универсальный формат моделей и материалов'),
              _modeTile(context, Icons.memory_rounded, 'Unity Scene JSON', 'координаты, камера, слои и объекты для Unity-модуля'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Профессиональные 3D объекты',
          trailing: 'FIFA style',
          child: Column(
            children: [
              _assetTile(context, Icons.person_rounded, '3D футболист', 'силуэт/манекен игрока с номером'),
              _assetTile(context, Icons.sports_soccer_rounded, 'Мяч', 'объект с тенью и масштабом'),
              _assetTile(context, Icons.traffic_rounded, 'Конус / маркер', 'тренировочные точки на поле'),
              _assetTile(context, Icons.height_rounded, '3D стрелка', 'стрелка с толщиной, высотой и тенью'),
              _assetTile(context, Icons.blur_circular_rounded, 'Объёмная зона', 'полупрозрачная зона с мягким свечением'),
              _assetTile(context, Icons.videocam_rounded, 'Камера трансляции', 'точка камеры для вида TV/тактика'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (selected != null)
          _Section(
            title: 'Выбранный объект',
            trailing: '3D props',
            child: Column(
              children: [
                _selectedObjectRow(selected),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _smallAction(context, 'В 3D слой', Icons.view_in_ar_rounded, () => _markElement(selected, layer: '3d'))),
                    const SizedBox(width: 8),
                    Expanded(child: _smallAction(context, 'Заблокировать', Icons.lock_rounded, () => _markElement(selected, locked: true))),
                  ],
                ),
              ],
            ),
          )
        else
          _Section(
            title: 'Выбранный объект',
            child: const Text('Выберите элемент на поле или в списке ниже, чтобы назначить ему 3D-слой и свойства.', style: TextStyle(color: _muted, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 12),
        _Section(
          title: 'Объекты на схеме',
          trailing: '${elements.length}',
          child: elements.isEmpty
              ? const Text('Пока нет объектов. Добавьте игрока, стрелку, зону или подпись.', style: TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w600))
              : Column(children: elements.map((e) => _sceneObjectTile(e)).toList()),
        ),
      ],
    );
  }

  Widget _modeTile(BuildContext context, IconData icon, String title, String subtitle) {
    return _cleanTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _hint(context, 'Выбран формат «$title». Реальный экспорт подключается отдельным шагом через JSON/GLB pipeline.'),
    );
  }

  Widget _assetTile(BuildContext context, IconData icon, String title, String subtitle) {
    return _cleanTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _hint(context, 'Объект «$title» добавлен как профессиональный 3D-пресет интерфейса. Следующий шаг — связать его с GLB-моделью/Unity prefab.'),
    );
  }

  Widget _cleanTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: const Color(0xFFF3FBF7), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 18, color: _green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedObjectRow(TgElement e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _green.withOpacity(.35))),
      child: Row(
        children: [
          Icon(_elementIcon(e), size: 18, color: _green),
          const SizedBox(width: 8),
          Expanded(child: Text(_elementTitle(e), style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900))),
          Text(e.layer == '3d' ? '3D' : '2D', style: TextStyle(color: e.layer == '3d' ? _green : _muted, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _sceneObjectTile(TgElement e) {
    final selected = state.selectedId == e.id;
    final is3d = e.layer == '3d';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFF3FBF7) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => state.selectById(e.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? _green : _border, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Icon(_elementIcon(e), size: 17, color: selected ? _green : _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_elementTitle(e), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(is3d ? '3D слой / экспортируемый объект' : '2D слой / схема', style: const TextStyle(color: _muted, fontSize: 10.2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _markElement(e, layer: is3d ? 'default' : '3d'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: is3d ? _green.withOpacity(.10) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: is3d ? _green.withOpacity(.45) : _border),
                    ),
                    child: Text(is3d ? '3D' : '+3D', style: TextStyle(color: is3d ? _green : _muted, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallAction(BuildContext context, String text, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: _green,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _green.withOpacity(.28))),
      ),
    );
  }

  void _markElement(TgElement e, {bool? locked, String? layer}) {
    final json = Map<String, dynamic>.from(e.toJson());
    if (locked != null) json['locked'] = locked;
    if (layer != null) json['layer'] = layer;
    state.replaceElement(TgElement.fromJson(json));
  }

  void _hint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }
}

class _ExportPanel extends _BasePanel {
  final TgState state;
  final VoidCallback? onExportPng;

  _ExportPanel({
    required this.state,
    this.onExportPng,
    required super.onClose,
  }) : super(
          title: 'Экспорт',
          icon: Icons.file_download,
          child: _ExportPanelContent(state: state, onExportPng: onExportPng),
        );
}

class _ExportPanelContent extends StatelessWidget {
  const _ExportPanelContent({required this.state, required this.onExportPng});
  final TgState state;
  final VoidCallback? onExportPng;

  static const _green = Color(0xFF00A750);
  static const _border = Color(0xFFE5E7EB);
  static const _txt = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: 'Форматы',
          trailing: 'pro',
          child: Column(
            children: [
              _exportTile(context, Icons.image, 'PNG 4K кадр', 'для отчёта, презентации, Telegram', onExportPng),
              _exportTile(context, Icons.view_in_ar_rounded, 'GLB / Unity сцена', 'поле + объекты + камера для 3D пайплайна', null),
              _exportTile(context, Icons.picture_as_pdf, 'PDF разбор', 'схема + список элементов + заметки', null),
              _exportTile(context, Icons.sports_soccer_rounded, 'FIFA overlay', 'прозрачные слои поверх видео/кадра', null),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Качество',
          trailing: 'broadcast',
          child: Column(
            children: const [
              _QualityRow('Разрешение', '3840 × 2160'),
              _QualityRow('FPS анимации', '30'),
              _QualityRow('Фон', 'поле + прозрачные слои'),
              _QualityRow('Стиль', 'FIFA / CMR'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Состояние сцены',
          child: Row(
            children: [
              Expanded(child: _stat('Объекты', '${state.elements.length}')),
              const SizedBox(width: 8),
              Expanded(child: _stat('3D', state.is3DMode ? 'ON' : 'OFF')),
              const SizedBox(width: 8),
              Expanded(child: _stat('Выбор', state.selected == null ? '—' : '1')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exportTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? () => _hint(context, 'Формат «$title» добавлен как pro-раздел интерфейса. Для реального файла нужен следующий шаг: backend/export или desktop file saver.'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
            child: Row(
              children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFF3FBF7), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: _green, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: _txt, fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: _muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: _txt, fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: _muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  void _hint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

IconData _elementIcon(TgElement element) {
  if (element is TgStamp) return Icons.person;
  if (element is TgLine) return Icons.trending_flat;
  if (element is TgRect) return Icons.crop_square;
  if (element is TgCircle) return Icons.circle_outlined;
  if (element is TgText) return Icons.text_fields;
  if (element is TgWavy || element is TgEditableWavy) return Icons.timeline;
  if (element is TgZigzag || element is TgEditableZigzag) return Icons.show_chart;
  if (element is TgSpring || element is TgEditableSpring) return Icons.all_inclusive;
  if (element is TgSpiral || element is TgEditableSpiral) return Icons.gesture;
  return Icons.layers;
}

String _elementTitle(TgElement element) {
  final custom = element.name?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  if (element is TgStamp) return 'Игрок / объект';
  if (element is TgLine) return 'Линия / стрелка';
  if (element is TgRect) return 'Зона';
  if (element is TgCircle) return 'Акцент / круг';
  if (element is TgText) return 'Титр / подпись';
  if (element is TgWavy || element is TgEditableWavy) return 'Маршрут / волна';
  if (element is TgZigzag || element is TgEditableZigzag) return 'Зигзаг';
  if (element is TgSpring || element is TgEditableSpring) return 'Пружина';
  if (element is TgSpiral || element is TgEditableSpiral) return 'Спираль';
  return 'Элемент';
}


// ==================== ОСНОВНАЯ ПАНЕЛЬ ====================
enum TgPanel { none, objects, templates, layers, assets3d, export, editor, threeD }

class TgRightPanel extends StatefulWidget {
  const TgRightPanel({
    super.key,
    required this.state,
    required this.stamps,
    this.onRefreshSvg,
    required this.canvasKey,
    this.onExportPng,
    this.teamName = '',
    this.teamPlayers = const <Map<String, dynamic>>[],
    this.teamPlayersLoading = false,
    this.teamPlayersError,
    this.onOpen3DPro,
    this.initialPanel = TgPanel.objects,
  });

  final TgState state;
  final List<String> stamps;
  final void Function(String asset, PlayerColors colors)? onRefreshSvg;
  final GlobalKey<TgCanvasState> canvasKey;
  final VoidCallback? onExportPng;
  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;
  final bool teamPlayersLoading;
  final String? teamPlayersError;
  final VoidCallback? onOpen3DPro;
  final TgPanel initialPanel;

  @override
  State<TgRightPanel> createState() => _TgRightPanelState();
}

class _TgRightPanelState extends State<TgRightPanel> {
  TgPanel _activePanel = TgPanel.objects;

  bool get _panelOpen => _activePanel != TgPanel.none;
  bool get _is3DActive => _activePanel == TgPanel.threeD;
  bool get _isObjectActive => _activePanel == TgPanel.objects;
  bool get _isTemplatesActive => _activePanel == TgPanel.templates;
  bool get _isLayersActive => _activePanel == TgPanel.layers;
  bool get _is3DObjectsActive => _activePanel == TgPanel.assets3d;
  bool get _isExportActive => _activePanel == TgPanel.export;
  bool get _isEditActive => _activePanel == TgPanel.editor;

  @override
  void initState() {
    super.initState();
    _activePanel = widget.initialPanel;
    widget.state.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant TgRightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPanel != widget.initialPanel) {
      setState(() => _activePanel = widget.initialPanel);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _closeAllPanels() {
    setState(() {
      _activePanel = TgPanel.none;
    });
  }

  void _openPanel(TgPanel panel, {bool enable3D = false}) {
    setState(() {
      if (_activePanel == panel) {
        _activePanel = TgPanel.none;
        if (widget.state.is3DMode && !enable3D) {
          widget.state.toggle3DMode();
        }
      } else {
        _activePanel = panel;
        if (enable3D) {
          if (!widget.state.is3DMode) widget.state.toggle3DMode();
        } else if (widget.state.is3DMode) {
          widget.state.toggle3DMode();
        }
      }
    });
  }

  void _openObjectPanel() => _openPanel(TgPanel.objects);
  void _openTemplatesPanel() => _openPanel(TgPanel.templates);
  void _openLayersPanel() => _openPanel(TgPanel.layers);
  void _open3DObjectsPanel() => _openPanel(TgPanel.assets3d);
  void _openExportPanel() => _openPanel(TgPanel.export);

  void _openEditorPanel() {
    if (widget.state.selected == null) return;
    _openPanel(TgPanel.editor);
  }

  void _open3DPanel() => _openPanel(TgPanel.threeD, enable3D: true);

  EdgeInsets _panelInsets(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    final bottom = mq.padding.bottom;
    return EdgeInsets.only(top: top + 12, bottom: bottom + 12);
  }

  @override
  Widget build(BuildContext context) {
    final safe = _panelInsets(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430 || MediaQuery.of(context).size.width < 1280 || MediaQuery.of(context).size.height < 820;
        final micro = constraints.maxWidth < 340 || MediaQuery.of(context).size.width < 900 || MediaQuery.of(context).size.height < 620;
        final dockRight = micro ? 4.0 : (compact ? 8.0 : 12.0);
        final dockWidth = micro ? 48.0 : (compact ? 54.0 : 62.0);
        final gap = micro ? 6.0 : (compact ? 8.0 : 14.0);
        final panelRight = dockRight + dockWidth + gap;
        final availablePanelWidth = constraints.maxWidth - panelRight - (micro ? 2.0 : 4.0);
        final panelWidth = math.min(
          micro ? 286.0 : 340.0,
          math.max(micro ? 172.0 : 220.0, availablePanelWidth),
        );

        return Stack(
      children: [
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
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _ObjectPanel(
              state: widget.state,
              stamps: widget.stamps,
              onObjectSelected: (asset) {
                widget.state.setActiveStamp(asset);
                widget.state.setTool(TgTool.stamp);
              },
              onPlayerSelected: (player) {
                final asset = _defaultPlayerStamp(widget.stamps, player);
                if (asset.isNotEmpty) {
                  widget.state.setActiveStamp(asset);
                  widget.state.setTool(TgTool.stamp);
                }
              },
              teamName: widget.teamName,
              teamPlayers: widget.teamPlayers,
              teamPlayersLoading: widget.teamPlayersLoading,
              teamPlayersError: widget.teamPlayersError,
              onOpen3DPro: widget.onOpen3DPro,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.templates)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _TemplatesPanel(
              state: widget.state,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.layers)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _LayersPanel(
              state: widget.state,
              onOpenProperties: _openEditorPanel,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.assets3d)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _ThreeDObjectsPanel(
              state: widget.state,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.export)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _ExportPanel(
              state: widget.state,
              onExportPng: widget.onExportPng,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.editor && widget.state.selected != null)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _EditorPanel(
              state: widget.state,
              onRefreshSvg: widget.onRefreshSvg,
              onClose: _closeAllPanels,
            ),
          ),
        if (_activePanel == TgPanel.threeD)
          Positioned(
            right: panelRight,
            top: safe.top,
            bottom: safe.bottom,
            width: panelWidth,
            child: _ThreeDPanel(
              state: widget.state,
              canvasKey: widget.canvasKey,
              onClose: _closeAllPanels,
            ),
          ),
        _QuickActionCircles(
          state: widget.state,
          onObjectSelected: _openObjectPanel,
          onTemplatesSelected: _openTemplatesPanel,
          onLayersSelected: _openLayersPanel,
          on3DObjectsSelected: _open3DObjectsPanel,
          onExportSelected: _openExportPanel,
          onEditSelected: _openEditorPanel,
          on3DSelected: _open3DPanel,
          isObjectActive: _isObjectActive,
          isTemplatesActive: _isTemplatesActive,
          isLayersActive: _isLayersActive,
          is3DObjectsActive: _is3DObjectsActive,
          isExportActive: _isExportActive,
          isEditActive: _isEditActive,
          is3DActive: _is3DActive,
        ),
      ],
    );
      },
    );
  }
}
