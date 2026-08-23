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

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String get name {
    final full = _s(player['full_name'] ?? player['name']);
    if (full.isNotEmpty) return full;
    final last = _s(player['last_name'] ?? player['lastName']);
    final first = _s(player['first_name'] ?? player['firstName']);
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String get subtitle => <String>[
        _s(player['position'] ?? player['role']),
        _s(player['number']).isEmpty ? '' : '№${_s(player['number'])}',
        _s(player['team_name']),
      ].where((item) => item.isNotEmpty).join(' · ');

  String? get photo {
    final raw = _s(player['photo'] ?? player['avatar'] ?? player['photo_url']);
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return raw.startsWith('/')
        ? 'https://sportotekaapp.ru$raw'
        : 'https://sportotekaapp.ru/uploads/$raw';
  }

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'И';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final veryCompact = constraints.maxWidth < 520;
        final avatarSize = veryCompact ? 48.0 : 58.0;

        return Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: EdgeInsets.symmetric(
            horizontal: embedded ? 12 : 16,
            vertical: 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: PpColors.line,
                width: .65,
              ),
            ),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: PpColors.soft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: photo == null
                        ? Center(
                            child: Text(
                              initials,
                              style: PpText.title(16),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: photo!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                initials,
                                style: PpText.title(16),
                              ),
                            ),
                          ),
                  ),
                  if (onPhotoEdit != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onPhotoEdit,
                      borderRadius: BorderRadius.circular(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          veryCompact ? 'Фото' : 'Изменить фото',
                          style: PpText.caption(
                            size: 9.5,
                            color: PpColors.greenDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: veryCompact ? 9 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PpText.title(compact ? 16 : 18),
                    ),
                    if (!veryCompact && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PpText.body(11),
                      ),
                    ],
                    const SizedBox(height: 7),
                    const PpDotCluster(),
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (onAi != null)
                    _HeaderAction(
                      label: compact ? 'ИИ' : 'ИИ игрока',
                      dotColor: PpColors.greenDark,
                      onTap: onAi,
                      emphasized: true,
                    ),
                  if (onMessage != null)
                    _HeaderAction(
                      label: compact ? 'Чат' : 'Сообщение',
                      dotColor: PpColors.green,
                      onTap: onMessage,
                    ),
                  if (onClose != null)
                    _HeaderAction(
                      label: '×',
                      dotColor: PpColors.muted2,
                      onTap: onClose,
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String label;
  final Color dotColor;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool compact;

  const _HeaderAction({
    required this.label,
    required this.dotColor,
    this.onTap,
    this.emphasized = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? PpColors.greenSoft : PpColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 11),
          alignment: Alignment.center,
          child: compact
              ? Text(
                  label,
                  style: PpText.title(14),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PpDot(
                      color: dotColor,
                      size: emphasized ? 6 : 5,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: PpText.body(
                        10.2,
                        color: emphasized
                            ? PpColors.greenDark
                            : PpColors.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
