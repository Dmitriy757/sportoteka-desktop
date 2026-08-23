import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cmr_club_ai_assistant_panel.dart';

/// Контекстный слой СПОРТОТЕКА ИИ.
///
/// Рабочий экран всегда занимает всю доступную область. В свёрнутом состоянии
/// остаётся только компактная плавающая кнопка, а раскрытый помощник появляется
/// как modal overlay поверх текущего раздела и закрывается без смены route.
class CmrContextAiLayer extends StatelessWidget {
  const CmrContextAiLayer({
    super.key,
    required this.child,
    required this.expanded,
    required this.onToggle,
    required this.clubId,
    required this.userId,
    required this.teamId,
    required this.clubName,
    required this.teamName,
    required this.contextTitle,
    required this.contextSubtitle,
    required this.initialPrompt,
    required this.initialPayload,
    this.panelKey,
    this.bottomInset = 10,
    this.playerOnlyMode = false,
    this.playerId,
    this.playerName,
    this.onNavigate,
    this.onOpenPdf,
  });

  final Widget child;
  final bool expanded;
  final VoidCallback onToggle;
  final int clubId;
  final int userId;
  final int? teamId;
  final String clubName;
  final String teamName;
  final String contextTitle;
  final String contextSubtitle;
  final String initialPrompt;
  final Map<String, dynamic> initialPayload;
  final Key? panelKey;
  final double bottomInset;
  final bool playerOnlyMode;
  final int? playerId;
  final String? playerName;
  final void Function(String target, Map<String, dynamic> payload)? onNavigate;
  final ValueChanged<String>? onOpenPdf;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        final safeBottom = math.max(8.0, bottomInset);
        final modalWidth = mobile
            ? math.max(280.0, constraints.maxWidth - 16)
            : math.min(560.0, math.max(420.0, constraints.maxWidth * .52));
        final availableHeight = math.max(
          1.0,
          constraints.maxHeight - (mobile ? safeBottom + 8 : 36),
        );
        final preferredHeight = mobile
            ? math.max(360.0, constraints.maxHeight * .88)
            : math.min(780.0, math.max(480.0, constraints.maxHeight * .88));
        final modalHeight = math.min(availableHeight, preferredHeight);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: child),
            Positioned.fill(
              child: Offstage(
                offstage: !expanded,
                child: _ModalBackdrop(
                  mobile: mobile,
                  width: modalWidth,
                  height: modalHeight,
                  bottomInset: safeBottom,
                  contextTitle: contextTitle,
                  contextSubtitle: contextSubtitle,
                  onDismiss: onToggle,
                  child: _assistant(),
                ),
              ),
            ),
            if (!expanded)
              Positioned(
                right: mobile ? 12 : 14,
                bottom: safeBottom,
                child: _CollapsedLauncher(
                  contextTitle: contextTitle,
                  onTap: onToggle,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _assistant() {
    return CmrClubAiAssistantPanel(
      key: panelKey,
      clubId: clubId,
      userId: userId,
      teamId: teamId,
      clubName: clubName,
      teamName: teamName,
      playerOnlyMode: playerOnlyMode,
      playerId: playerId,
      playerName: playerName,
      initialPrompt: initialPrompt,
      initialPayload: initialPayload,
      autoSendInitialPrompt: expanded,
      onNavigate: onNavigate,
      onOpenPdf: onOpenPdf,
    );
  }
}

class _ModalBackdrop extends StatelessWidget {
  const _ModalBackdrop({
    required this.mobile,
    required this.width,
    required this.height,
    required this.bottomInset,
    required this.contextTitle,
    required this.contextSubtitle,
    required this.onDismiss,
    required this.child,
  });

  final bool mobile;
  final double width;
  final double height;
  final double bottomInset;
  final String contextTitle;
  final String contextSubtitle;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: ColoredBox(
                  color: Colors.black.withOpacity(.28 * value),
                )
              ),
            ),
            Positioned(
              left: mobile ? 8 : null,
              right: mobile ? 8 : 18,
              bottom: mobile ? bottomInset : null,
              top: mobile ? null : 18,
              width: mobile ? null : width,
              height: height,
              child: Transform.translate(
                offset: Offset((1 - value) * (mobile ? 0 : 32), (1 - value) * (mobile ? 24 : 0)),
                child: Opacity(
                  opacity: value,
                  child: GestureDetector(
                    onTap: () {},
                    child: Material(
                      color: Colors.white,
                      elevation: 18,
                      shadowColor: const Color(0x330F172A),
                      borderRadius: BorderRadius.circular(mobile ? 24 : 20),
                      clipBehavior: Clip.antiAlias,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDDE7E1)),
                          borderRadius: BorderRadius.circular(mobile ? 24 : 20),
                        ),
                        child: Column(
                          children: [
                            _ExpandedHeader(
                              contextTitle: contextTitle,
                              contextSubtitle: contextSubtitle,
                              onDismiss: onDismiss,
                            ),
                            const Divider(height: 1, color: Color(0xFFE7ECE9)),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.contextTitle,
    required this.contextSubtitle,
    required this.onDismiss,
  });

  final String contextTitle;
  final String contextSubtitle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
      color: const Color(0xFFF7FBF8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFE3F6EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF07883F),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'СПОРТОТЕКА ИИ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 13.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7EF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'КОНТЕКСТ',
                        style: TextStyle(
                          color: Color(0xFF087A3A),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$contextTitle · $contextSubtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Закрыть ИИ-помощника',
            onPressed: onDismiss,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF667085),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedLauncher extends StatelessWidget {
  const _CollapsedLauncher({
    required this.contextTitle,
    required this.onTap,
  });

  final String contextTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'СПОРТОТЕКА ИИ · $contextTitle',
      child: Material(
        color: Colors.white,
        elevation: 7,
        shadowColor: const Color(0x260F172A),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFD7E5DC)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF07883F),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
