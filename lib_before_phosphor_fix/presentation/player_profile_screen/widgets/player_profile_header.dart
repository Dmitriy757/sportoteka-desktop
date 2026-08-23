import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'player_profile_ui.dart';

class PlayerProfileHeader extends StatelessWidget {
  final Map<String, dynamic> player;
  final VoidCallback? onClose;
  final VoidCallback? onPhotoEdit;
  final VoidCallback? onMessage;
  final VoidCallback? onAi;
  final bool embedded;

  const PlayerProfileHeader({
    super.key,
    required this.player,
    this.onClose,
    this.onPhotoEdit,
    this.onMessage,
    this.onAi,
    required this.embedded,
  });

  String _s(dynamic v) => '${v ?? ''}'.trim();

  String get name {
    final full = _s(player['full_name'] ?? player['name']);
    if (full.isNotEmpty) return full;
    return '${_s(player['first_name'])} ${_s(player['last_name'])}'.trim();
  }

  String get subtitle => [
        _s(player['position'] ?? player['role']),
        _s(player['number']).isEmpty ? '' : '№${_s(player['number'])}',
        _s(player['team_name']),
      ].where((e) => e.isNotEmpty).join(' · ');

  String? get photo {
    final raw = _s(player['photo'] ?? player['avatar'] ?? player['photo_url']);
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return raw.startsWith('/')
        ? 'https://sportotekaapp.ru$raw'
        : 'https://sportotekaapp.ru/uploads/$raw';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 660;
        final veryCompact = constraints.maxWidth < 520;
        final avatarWidth = veryCompact ? 58.0 : 72.0;
        final avatarSize = veryCompact ? 48.0 : 58.0;

        return Container(
          height: 104,
          padding: EdgeInsets.symmetric(horizontal: embedded ? 12 : 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: PpColors.line, width: .7)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: avatarWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        color: PpColors.soft2,
                        child: photo == null
                            ? const Icon(Icons.person_rounded, color: PpColors.muted)
                            : CachedNetworkImage(
                                imageUrl: photo!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.person_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onPhotoEdit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          veryCompact ? 'Фото' : 'Изменить фото',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(9.2, color: PpColors.green, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: veryCompact ? 6 : 10),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Игрок' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: PpText.title(compact ? 16 : 18),
                      ),
                      if (!veryCompact && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(11.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              if (compact)
                _HeaderIconButton(
                  icon: Icons.auto_awesome_rounded,
                  tooltip: 'ИИ игрока',
                  onTap: onAi,
                  accent: true,
                )
              else
                _AiHeaderButton(onTap: onAi),
              SizedBox(width: compact ? 4 : 7),
              if (compact)
                _HeaderIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: 'Сообщение',
                  onTap: onMessage,
                )
              else
                _HeaderButton(label: 'Сообщение', onTap: onMessage),
              if (onClose != null) ...[
                SizedBox(width: compact ? 2 : 7),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  tooltip: 'Закрыть',
                  visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                  padding: compact ? EdgeInsets.zero : null,
                  constraints: compact ? const BoxConstraints.tightFor(width: 36, height: 36) : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

}


class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool accent;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent ? PpColors.greenSoft : PpColors.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color: accent ? PpColors.greenDark : PpColors.text,
              ),
            ),
          ),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HeaderButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: PpColors.text,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: PpColors.soft,
        ),
        child: Text(label, style: PpText.body(11.5, color: PpColors.text, weight: FontWeight.w600)),
      );
}


class _AiHeaderButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AiHeaderButton({this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: PpColors.greenDark),
                const SizedBox(width: 6),
                Text('ИИ игрока', style: PpText.body(11.5, color: PpColors.greenDark, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}
