import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cmr_club_ai_assistant_panel.dart';

/// Встроенный контекстный слой СПОРТОТЕКА ИИ.
///
/// Это не route, dialog или bottom sheet: панель живёт в Stack текущего
/// рабочего экрана и поэтому не выбрасывает тренера из Club Workspace/Tracker.
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
        final tablet =
            constraints.maxWidth >= 720 && constraints.maxWidth < 1120;
        final safeBottom = math.max(8.0, bottomInset);
        final expandedWidth = math.min(
          tablet ? 390.0 : 430.0,
          math.max(320.0, constraints.maxWidth * (tablet ? .46 : .34)),
        );
        final expandedHeight = math.min(
          660.0,
          math.max(360.0, constraints.maxHeight * .74),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: child),
            if (mobile)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: 8,
                right: 8,
                bottom: safeBottom,
                height: expanded ? expandedHeight : 58,
                child: _LayerSurface(
                  expanded: expanded,
                  mobile: true,
                  contextTitle: contextTitle,
                  contextSubtitle: contextSubtitle,
                  onToggle: onToggle,
                  child: expanded ? _assistant() : null,
                ),
              )
            else
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                top: 10,
                right: 10,
                bottom: safeBottom,
                width: expanded ? expandedWidth : 58,
                child: _LayerSurface(
                  expanded: expanded,
                  mobile: false,
                  contextTitle: contextTitle,
                  contextSubtitle: contextSubtitle,
                  onToggle: onToggle,
                  child: expanded ? _assistant() : null,
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
      autoSendInitialPrompt: true,
      onNavigate: onNavigate,
      onOpenPdf: onOpenPdf,
    );
  }
}

class _LayerSurface extends StatelessWidget {
  const _LayerSurface({
    required this.expanded,
    required this.mobile,
    required this.contextTitle,
    required this.contextSubtitle,
    required this.onToggle,
    this.child,
  });

  final bool expanded;
  final bool mobile;
  final String contextTitle;
  final String contextSubtitle;
  final VoidCallback onToggle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(expanded ? 18 : 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(expanded ? 18 : 16),
            border: Border.all(color: const Color(0xFFDDE7E1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x240F172A),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: expanded
              ? Column(
                  children: [
                    _ExpandedHeader(
                      contextTitle: contextTitle,
                      contextSubtitle: contextSubtitle,
                      onToggle: onToggle,
                    ),
                    const Divider(height: 1, color: Color(0xFFE7ECE9)),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                )
              : _CollapsedHandle(
                  mobile: mobile,
                  contextTitle: contextTitle,
                  onTap: onToggle,
                ),
        ),
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.contextTitle,
    required this.contextSubtitle,
    required this.onToggle,
  });

  final String contextTitle;
  final String contextSubtitle;
  final VoidCallback onToggle;

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
            tooltip: 'Свернуть ИИ-слой',
            onPressed: onToggle,
            icon: const Icon(
              Icons.keyboard_double_arrow_right_rounded,
              color: Color(0xFF667085),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedHandle extends StatelessWidget {
  const _CollapsedHandle({
    required this.mobile,
    required this.contextTitle,
    required this.onTap,
  });

  final bool mobile;
  final String contextTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = mobile
        ? Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF07883F), size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'СПОРТОТЕКА ИИ · $contextTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const Text('Советы',
                  style: TextStyle(
                      color: Color(0xFF087A3A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFF667085), size: 20),
              const SizedBox(width: 8),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF07883F), size: 22),
              const SizedBox(height: 12),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'СПОРТОТЕКА ИИ',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 10.4,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.keyboard_double_arrow_left_rounded,
                  color: Color(0xFF667085), size: 19),
            ],
          );

    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: 'Открыть контекстный ИИ-анализ: $contextTitle',
        child: content,
      ),
    );
  }
}
