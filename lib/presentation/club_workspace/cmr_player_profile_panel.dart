// lib/presentation/club_workspace/cmr_player_profile_panel.dart
// Windows 11 / Fluent refresh based on CmrClubTeamsPanel typography and glass cards.
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class CmrPlayerProfilePanel extends StatefulWidget {
  final Map<String, dynamic>? player;
  final String teamName;
  final VoidCallback? onOpenEditor;
  final VoidCallback? onDeletePlayer;
  final VoidCallback? onMessagePlayer;
  final VoidCallback? onAssignTraining;
  final VoidCallback? onClose;
  final bool showModalChrome;

  const CmrPlayerProfilePanel({
    super.key,
    required this.player,
    required this.teamName,
    this.onOpenEditor,
    this.onDeletePlayer,
    this.onMessagePlayer,
    this.onAssignTraining,
    this.onClose,
    this.showModalChrome = false,
  });

  @override
  State<CmrPlayerProfilePanel> createState() => _CmrPlayerProfilePanelState();
}

Future<void> showCmrPlayerProfileSheet({
  required BuildContext context,
  required Map<String, dynamic> player,
  required String teamName,
  VoidCallback? onOpenEditor,
  VoidCallback? onDeletePlayer,
  VoidCallback? onMessagePlayer,
  VoidCallback? onAssignTraining,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.18),
    builder: (sheetContext) => _PlayerProfileModalSheet(
      player: player,
      teamName: teamName,
      onOpenEditor: onOpenEditor,
      onDeletePlayer: onDeletePlayer,
      onMessagePlayer: onMessagePlayer,
      onAssignTraining: onAssignTraining,
    ),
  );
}

class _PlayerProfileModalSheet extends StatelessWidget {
  final Map<String, dynamic> player;
  final String teamName;
  final VoidCallback? onOpenEditor;
  final VoidCallback? onDeletePlayer;
  final VoidCallback? onMessagePlayer;
  final VoidCallback? onAssignTraining;

  const _PlayerProfileModalSheet({
    required this.player,
    required this.teamName,
    this.onOpenEditor,
    this.onDeletePlayer,
    this.onMessagePlayer,
    this.onAssignTraining,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = math.min(screen.height * .92, 760.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset > 0 ? bottomInset : 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: sheetHeight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CmrPlayerProfilePanel(
              player: player,
              teamName: teamName,
              onOpenEditor: onOpenEditor,
              onDeletePlayer: onDeletePlayer,
              onMessagePlayer: onMessagePlayer,
              onAssignTraining: onAssignTraining,
              showModalChrome: true,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PlayerProfileTab { overview, team, contacts }

class _CmrPlayerProfilePanelState extends State<CmrPlayerProfilePanel> {
  _PlayerProfileTab _tab = _PlayerProfileTab.overview;

  @override
  void didUpdateWidget(covariant CmrPlayerProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget.player) != _identity(widget.player)) {
      _tab = _PlayerProfileTab.overview;
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return Container(
      decoration: _ProfileDecor.panel(),
      clipBehavior: Clip.antiAlias,
      child: player == null ? const _EmptyPlayerProfile() : _buildProfile(player),
    );
  }

  Widget _buildProfile(Map<String, dynamic> player) {
    final name = _playerName(player);
    final photo = _absoluteUrl(_first(player, const ['photo', 'avatar', 'image', 'photo_url', 'avatar_url']));
    final position = _playerPosition(player).isEmpty ? 'Амплуа не указано' : _playerPosition(player);
    final number = _first(player, const ['number', 'player_number', 'shirt_number'], '—');
    final birth = _first(player, const ['birthDate', 'birth_date', 'birthday'], '—');
    final height = _first(player, const ['height'], '—');
    final weight = _first(player, const ['weight'], '—');
    final nationality = _first(player, const ['nationality', 'citizenship', 'nationa'], '—');
    final email = _first(player, const ['email'], '—');
    final phone = _first(player, const ['phone', 'telephone', 'phone_number', 'mobile'], '—');
    final sportData = _first(player, const ['sport_data', 'sportData']);

    return Column(
      children: [
        if (widget.showModalChrome)
          _ProfileModalTopBar(
            name: name,
            onClose: widget.onClose ??
                () {
                  Navigator.of(context).maybePop();
                },
          ),
        _ProfileHero(
          name: name,
          photo: photo,
          position: position,
          number: number,
          teamName: widget.teamName,
        ),
        _ProfileQuickActions(
          onOpenEditor: widget.onOpenEditor,
          onMessagePlayer: widget.onMessagePlayer,
          onAssignTraining: widget.onAssignTraining,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _ProfileTabs(
            selected: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildTab(
              key: ValueKey(_tab),
              player: player,
              birth: birth,
              height: height,
              weight: weight,
              nationality: nationality,
              email: email,
              phone: phone,
              sportData: sportData,
              position: position,
              number: number,
            ),
          ),
        ),
        if (widget.onDeletePlayer != null)
          _ProfileBottomDanger(
            onDeletePlayer: widget.onDeletePlayer!,
          ),
      ],
    );
  }

  Widget _buildTab({
    required Key key,
    required Map<String, dynamic> player,
    required String birth,
    required String height,
    required String weight,
    required String nationality,
    required String email,
    required String phone,
    required String sportData,
    required String position,
    required String number,
  }) {
    switch (_tab) {
      case _PlayerProfileTab.overview:
        return _ProfileScroll(
          key: key,
          children: [
            _ProfileInfoList(
              items: [
                _ProfileInfoData(Icons.cake_rounded, 'Дата рождения', birth == '—' ? 'Не указана' : birth),
                _ProfileInfoData(Icons.sports_soccer_rounded, 'Амплуа', position),
                _ProfileInfoData(Icons.tag_rounded, 'Игровой номер', number == '—' || number.isEmpty ? 'Не указан' : '№ $number'),
                _ProfileInfoData(Icons.height_rounded, 'Рост', height == '—' ? 'Не указан' : height),
                _ProfileInfoData(Icons.monitor_weight_outlined, 'Вес', weight == '—' ? 'Не указан' : weight),
                _ProfileInfoData(Icons.flag_rounded, 'Гражданство', nationality == '—' ? 'Не указано' : nationality),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.query_stats_rounded,
              title: 'Спортивные данные',
              child: Text(
                sportData.isEmpty ? 'Спортивные данные пока не заполнены. Нажмите «Редактировать», чтобы дополнить профиль игрока.' : sportData,
                style: sportData.isEmpty ? _ProfileText.muted(13.2) : _ProfileText.value(13.5),
              ),
            ),
          ],
        );

      case _PlayerProfileTab.team:
        return _ProfileTeamTab(
          key: key,
          teamName: widget.teamName,
          position: position,
          number: number,
          nationality: nationality,
        );

      case _PlayerProfileTab.contacts:
        return _ProfileContactsTab(
          key: key,
          email: email,
          phone: phone,
          onMessagePlayer: widget.onMessagePlayer,
        );
    }
  }
}

// Диалог для полноэкранного просмотра фото
class _FullscreenPhotoDialog extends StatelessWidget {
  final String photoUrl;
  final String name;

  const _FullscreenPhotoDialog({
    required this.photoUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF3A3F47),
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                photoUrl,
                errorBuilder: (_, __, ___) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить фото',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileModalTopBar extends StatelessWidget {
  final String name;
  final VoidCallback onClose;

  const _ProfileModalTopBar({
    required this.name,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Column(
        children: [
          const _ProfileSheetHandle(),
          Row(
            children: [
              _RoundIcon(icon: Icons.badge_rounded, color: _ProfileColors.green, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Профиль игрока', style: _ProfileText.title(16)),
                    const SizedBox(height: 2),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ProfileText.muted(12)),
                  ],
                ),
              ),
              Material(
                color: _ProfileColors.soft,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onClose,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.close_rounded, color: _ProfileColors.text, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSheetHandle extends StatelessWidget {
  const _ProfileSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD0D5DD),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String photo;
  final String position;
  final String number;
  final String teamName;

  const _ProfileHero({
    required this.name,
    required this.photo,
    required this.position,
    required this.number,
    required this.teamName,
  });

  void _showFullscreenPhoto(BuildContext context) {
    if (photo.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => _FullscreenPhotoDialog(photoUrl: photo, name: name),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ProfileColors.greenSoft, _ProfileColors.blueSoft.withOpacity(.82), _ProfileColors.pinkSoft.withOpacity(.52)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(.82)),
        boxShadow: [BoxShadow(color: _ProfileColors.green.withOpacity(.11), blurRadius: 24, spreadRadius: -12, offset: const Offset(0, 12))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: photo.isNotEmpty ? () => _showFullscreenPhoto(context) : null,
            child: Stack(
              children: [
                _EnhancedAvatar(photo: photo, name: name, size: 76),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: _ProfileColors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _ProfileText.title(20)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _HeaderPill(text: position, icon: Icons.sports_soccer_rounded, color: _ProfileColors.green),
                    _HeaderPill(text: number == '—' || number.isEmpty ? 'Номер не указан' : '№ $number', icon: Icons.tag_rounded),
                    _HeaderPill(text: teamName.isEmpty ? 'Команда не указана' : teamName, icon: Icons.groups_2_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _HeaderPill({
    required this.text,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(.92), (color == null ? _ProfileColors.blueSoft : color!.withOpacity(.10))],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(.78)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? _ProfileColors.muted),
          const SizedBox(width: 5),
Text(text, style: _ProfileText.muted(12)),
        ],
      ),
    );
  }
}

class _ProfileQuickActions extends StatelessWidget {
  final VoidCallback? onOpenEditor;
  final VoidCallback? onMessagePlayer;
  final VoidCallback? onAssignTraining;

  const _ProfileQuickActions({
    required this.onOpenEditor,
    required this.onMessagePlayer,
    required this.onAssignTraining,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ProfileActionTile(
        icon: Icons.message_rounded,
        label: 'Сообщение',
        color: _ProfileColors.green,
        onTap: onMessagePlayer,
        disabled: onMessagePlayer == null,
      ),
      _ProfileActionTile(
        icon: Icons.edit_rounded,
        label: 'Карточка',
        color: _ProfileColors.blue,
        onTap: onOpenEditor,
        disabled: onOpenEditor == null,
      ),
      _ProfileActionTile(
        icon: Icons.fitness_center_rounded,
        label: 'Тренировка',
        color: _ProfileColors.amber,
        onTap: onAssignTraining,
        disabled: onAssignTraining == null,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(disabled ? .05 : .13)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(.82)),
            boxShadow: disabled ? null : [BoxShadow(color: color.withOpacity(.12), blurRadius: 18, spreadRadius: -10, offset: const Offset(0, 9))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDangerInlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileDangerInlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileColors.red.withOpacity(.09),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _ProfileColors.red),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ProfileText.danger()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBottomDanger extends StatelessWidget {
  final VoidCallback onDeletePlayer;

  const _ProfileBottomDanger({required this.onDeletePlayer});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: _ProfileDangerInlineButton(
          icon: Icons.delete_outline_rounded,
          label: 'Удалить игрока',
          onTap: onDeletePlayer,
        ),
      ),
    );
  }
}

// Исправленный аватар без бесконечной загрузки
class _EnhancedAvatar extends StatefulWidget {
  final String photo;
  final String name;
  final double size;

  const _EnhancedAvatar({
    required this.photo,
    required this.name,
    required this.size,
  });

  @override
  State<_EnhancedAvatar> createState() => _EnhancedAvatarState();
}

class _EnhancedAvatarState extends State<_EnhancedAvatar> {
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resetLoadingState();
  }

  @override
  void didUpdateWidget(_EnhancedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) {
      _resetLoadingState();
    }
  }

  void _resetLoadingState() {
    _hasError = false;
    _isLoading = widget.photo.isNotEmpty;
  }

  void _onImageLoaded() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onImageError() {
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(widget.name);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _ProfileColors.soft,
        borderRadius: BorderRadius.circular(widget.size * .32),
        boxShadow: widget.photo.isNotEmpty && !_hasError
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.055),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasError || widget.photo.isEmpty
          ? Center(
              child: Text(
                initials,
                style: _ProfileText.title(widget.size * .32),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.photo,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      // Изображение загружено
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _onImageLoaded();
                      });
                      return child;
                    }
                    // Показываем индикатор загрузки только первые 2 секунды
                    return Center(
                      child: SizedBox(
                        width: widget.size * 0.3,
                        height: widget.size * 0.3,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _ProfileColors.green,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    _onImageError();
                    return Center(
                      child: Text(
                        initials,
                        style: _ProfileText.title(widget.size * .32),
                      ),
                    );
                  },
                ),
                // Затемнение для индикатора загрузки
                if (_isLoading)
                  Container(
                    color: Colors.white.withOpacity(0.5),
                  ),
              ],
            ),
    );
  }
}

class _EnhancedProfileButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _EnhancedProfileButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_EnhancedProfileButton> createState() => _EnhancedProfileButtonState();
}

class _EnhancedProfileButtonState extends State<_EnhancedProfileButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hovered) {
    setState(() => _isHovered = hovered);
    if (hovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                gradient: _isHovered
                    ? LinearGradient(
                        colors: [
                          _ProfileColors.green,
                          _ProfileColors.greenDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [_ProfileColors.greenSoft, _ProfileColors.greenSoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isHovered ? Colors.transparent : const Color(0xFFEFF1F4),
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: _ProfileColors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: _isHovered ? Colors.white : _ProfileColors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: _isHovered ? Colors.white : _ProfileColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

// Улучшенная сетка метрик с анимацией
class _EnhancedMetricGrid extends StatelessWidget {
  final List<_MetricData> items;

  const _EnhancedMetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 860 ? 4 : constraints.maxWidth >= 610 ? 3 : 2;
        final spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (int i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: _EnhancedMetricCard(
                  data: items[i],
                  animationDelay: i * 50,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EnhancedMetricCard extends StatefulWidget {
  final _MetricData data;
  final int animationDelay;

  const _EnhancedMetricCard({
    required this.data,
    required this.animationDelay,
  });

  @override
  State<_EnhancedMetricCard> createState() => _EnhancedMetricCardState();
}

class _EnhancedMetricCardState extends State<_EnhancedMetricCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isNumericValue(String value) {
    final numericRegex = RegExp(r'^[\d\.]+$');
    return numericRegex.hasMatch(value);
  }

  double? _getNumericValue(String value) {
    if (_isNumericValue(value)) {
      return double.tryParse(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final numericValue = _getNumericValue(widget.data.value);
    final isProgressMetric = numericValue != null && 
        (widget.data.title.contains('Рост') || 
         widget.data.title.contains('Вес') ||
         widget.data.title.contains('Скорость') ||
         widget.data.title.contains('Выносливость'));

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _ProfileDecor.softCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(icon: widget.data.icon, color: _ProfileColors.green),
              const SizedBox(height: 10),
              Text(widget.data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ProfileText.caption()),
              const SizedBox(height: 5),
              if (isProgressMetric && numericValue != null && numericValue <= 100)
                Column(
                  children: [
                    Text(
                      widget.data.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _ProfileText.value(15),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: numericValue / 100,
                        backgroundColor: _ProfileColors.soft,
                        valueColor: AlwaysStoppedAnimation<Color>(_ProfileColors.green),
                        minHeight: 4,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  widget.data.value.isEmpty ? '—' : widget.data.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _ProfileText.value(15),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  final _PlayerProfileTab selected;
  final ValueChanged<_PlayerProfileTab> onChanged;

  const _ProfileTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <_ProfileTabItem>[
      _ProfileTabItem(_PlayerProfileTab.overview, 'Обзор'),
      _ProfileTabItem(_PlayerProfileTab.team, 'Команда'),
      _ProfileTabItem(_PlayerProfileTab.contacts, 'Связь'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _ProfileColors.soft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _ProfileTabButton(
                title: item.title,
                selected: selected == item.tab,
                onTap: () => onChanged(item.tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_ProfileColors.green, _ProfileColors.blue])
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [BoxShadow(color: _ProfileColors.green.withOpacity(.16), blurRadius: 18, spreadRadius: -10, offset: const Offset(0, 8))]
                : null,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? _ProfileText.tabSelected().copyWith(color: Colors.white)
                : _ProfileText.tab().copyWith(color: _ProfileColors.muted, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabItem {
  final _PlayerProfileTab tab;
  final String title;

  const _ProfileTabItem(this.tab, this.title);
}

class _ProfileScroll extends StatelessWidget {
  final List<Widget> children;
  final double topPadding;

  const _ProfileScroll({super.key, required this.children, this.topPadding = 14});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 18),
      children: children,
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;

  const _MetricData(this.title, this.value, this.icon);
}

class _ProfileInfoData {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoData(this.icon, this.label, this.value);
}

class _ProfileInfoList extends StatelessWidget {
  final List<_ProfileInfoData> items;

  const _ProfileInfoList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _ProfileInfoRow(
            icon: items[i].icon,
            label: items[i].label,
            value: items[i].value,
          ),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _ProfileDecor.softCard(radius: 20),
      child: Row(
        children: [
          _RoundIcon(icon: icon, color: _ProfileColors.green, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ProfileText.caption()),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: _ProfileText.value(13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTeamTab extends StatelessWidget {
  final String teamName;
  final String position;
  final String number;
  final String nationality;

  const _ProfileTeamTab({
    super.key,
    required this.teamName,
    required this.position,
    required this.number,
    required this.nationality,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileScroll(
      key: key,
      children: [
        _ProfileInfoList(
          items: [
            _ProfileInfoData(Icons.shield_outlined, 'Команда', teamName.isEmpty ? 'Команда не указана' : teamName),
            _ProfileInfoData(Icons.sports_soccer_rounded, 'Амплуа', position.isEmpty ? 'Не указано' : position),
            _ProfileInfoData(Icons.tag_rounded, 'Игровой номер', number == '—' || number.isEmpty ? 'Не указан' : '№ $number'),
            _ProfileInfoData(Icons.flag_rounded, 'Гражданство', nationality == '—' || nationality.isEmpty ? 'Не указано' : nationality),
          ],
        ),
      ],
    );
  }
}

class _ProfileContactsTab extends StatelessWidget {
  final String email;
  final String phone;
  final VoidCallback? onMessagePlayer;

  const _ProfileContactsTab({
    super.key,
    required this.email,
    required this.phone,
    required this.onMessagePlayer,
  });

  @override
  Widget build(BuildContext context) {
    final hasEmail = email.trim().isNotEmpty && email != '—';
    final hasPhone = phone.trim().isNotEmpty && phone != '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: [
          _ProfileContactCard(
            icon: Icons.phone_rounded,
            label: 'Телефон',
            value: hasPhone ? phone : 'Не указан',
            color: _ProfileColors.green,
          ),
          const SizedBox(height: 10),
          _ProfileContactCard(
            icon: Icons.mail_rounded,
            label: 'Email',
            value: hasEmail ? email : 'Не указан',
            color: _ProfileColors.blue,
          ),
          const SizedBox(height: 12),
          const _ProfileNotice(
            icon: Icons.info_outline_rounded,
            title: 'Быстрая связь',
            text: 'Кнопка «Сообщение» сверху откроет личный чат с игроком.',
          ),
        ],
      ),
    );
  }
}

class _ProfileContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ProfileContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(15),
      decoration: _ProfileDecor.softCard(radius: 22),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _ProfileText.caption()),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: _ProfileColors.text),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, color: _ProfileColors.muted, size: 22),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _ProfileNotice({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _ProfileDecor.softCard(radius: 24),
      child: Row(
        children: [
          _RoundIcon(icon: icon, color: _ProfileColors.green, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _ProfileText.title(14)),
                const SizedBox(height: 4),
                Text(text, style: _ProfileText.muted(13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _ProfileDecor.softCard(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIcon(icon: icon, color: _ProfileColors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _ProfileText.section())),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SoftState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _SoftState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _ProfileDecor.softCard(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundIcon(icon: icon, color: _ProfileColors.green, size: 44),
          const SizedBox(height: 16),
          Text(title, style: _ProfileText.title(20)),
          const SizedBox(height: 8),
          Text(text, style: _ProfileText.muted(14)),
        ],
      ),
    );
  }
}

class _EmptyPlayerProfile extends StatelessWidget {
  const _EmptyPlayerProfile();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _SoftState(
        icon: Icons.person_search_rounded,
        title: 'Выберите игрока',
        text: 'Нажмите на карточку в составе — профиль откроется здесь же, без перехода на новый экран.',
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Pill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _ProfileColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ProfileColors.muted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ProfileText.pill()),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RoundIcon({
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color == _ProfileColors.green ? _ProfileColors.greenSoft : _ProfileColors.soft,
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(icon, size: size * .52, color: color),
    );
  }
}

class _ProfileColors {
  static const Color panel = Colors.white;
  static const Color glass = Color(0xF7FFFFFF);
  static const Color soft = Color(0xFFFAFBFA);
  static const Color soft2 = Color(0xFFF4F6F4);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF6B7280);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanSoft = Color(0xFFEFFBFF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F0FF);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkSoft = Color(0xFFFFF1F8);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFD92D20);
}


Color _profileAccent(int index) => _ProfileColors.green;

Color _profileAccentSoft(int index) => _ProfileColors.greenSoft;

class _ProfileDecor {
  static BoxDecoration panel() => BoxDecoration(
        color: _ProfileColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EBE8), width: .8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 26,
            spreadRadius: -14,
            offset: const Offset(0, 14),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 14}) => BoxDecoration(
        color: _ProfileColors.soft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE7EBE8), width: .7),
      );
}


class _ProfileText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _ProfileColors.text,
        height: 1.12,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle section() =>
      AppTypography.sectionTitle(color: _ProfileColors.text);

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _ProfileColors.text,
        height: 1.22,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _ProfileColors.muted,
        height: 1.36,
      );

  static TextStyle caption() =>
      AppTypography.captionMedium(color: _ProfileColors.muted);

  static TextStyle pill() =>
      AppTypography.chip(color: _ProfileColors.text);

  static TextStyle tab() =>
      AppTypography.tab(color: _ProfileColors.text);

  static TextStyle tabSelected() =>
      AppTypography.tab(color: _ProfileColors.green, active: true);

  static TextStyle action() =>
      AppTypography.action(color: _ProfileColors.green);

  static TextStyle danger() =>
      AppTypography.action(color: _ProfileColors.red);
}

class _KnownMetric {
  final String title;
  final List<String> keys;
  final IconData icon;

  const _KnownMetric(this.title, this.keys, this.icon);
}

List<_MetricData> _extractMetrics(Map<String, dynamic> player, String sportData) {
  final result = <_MetricData>[];

  final known = <_KnownMetric>[
    _KnownMetric('Рост', const ['height'], Icons.height_rounded),
    _KnownMetric('Вес', const ['weight'], Icons.monitor_weight_outlined),
    _KnownMetric('Голы', const ['goals'], Icons.sports_soccer_rounded),
    _KnownMetric('Передачи', const ['assists'], Icons.call_split_rounded),
    _KnownMetric('Скорость', const ['speed'], Icons.speed_rounded),
    _KnownMetric('Выносливость', const ['stamina'], Icons.bolt_rounded),
  ];

  for (final item in known) {
    final value = _first(player, item.keys);
    if (value.isNotEmpty) result.add(_MetricData(item.title, value, item.icon));
  }

  if (sportData.isNotEmpty) {
    final parts = sportData
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length <= 38)
        .take(8)
        .toList();

    for (final part in parts) {
      final chunks = part.split(RegExp(r'[:=]'));
      if (chunks.length >= 2) {
        final title = chunks.first.trim();
        final value = chunks.sublist(1).join(':').trim();
        if (title.isNotEmpty && value.isNotEmpty) {
          result.add(_MetricData(title, value, Icons.insights_rounded));
        }
      }
    }
  }

  final seen = <String>{};
  return result.where((item) => seen.add('${item.title}:${item.value}'.toLowerCase())).toList();
}

String _identity(Map<String, dynamic>? player) {
  if (player == null) return '';
  for (final key in const ['id', 'player_id', 'playerId', 'user_id', 'userId']) {
    final value = _s(player[key]);
    if (value.isNotEmpty && value != '0') return '$key:$value';
  }
  return _playerName(player);
}

String _s(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text == 'null' ? '' : text;
}

String _first(Map<String, dynamic> map, List<String> keys, [String fallback = '']) {
  for (final key in keys) {
    final value = _s(map[key]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _playerName(Map<String, dynamic> player) {
  final first = _first(player, const ['first_name', 'firstname']);
  final last = _first(player, const ['last_name', 'lastname']);
  final full = _first(player, const ['fullName', 'full_name', 'name']);
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  return full.isEmpty ? 'Игрок' : full;
}

String _playerPosition(Map<String, dynamic> player) {
  return _first(player, const ['position', 'role', 'amplua']);
}

String _absoluteUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final cleaned = value.startsWith('/') ? value.substring(1) : value;
  return 'https://sportotekaapp.ru/$cleaned';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'И';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}