import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';

enum WorkspaceWindowSnap { none, left, right, maximized }

class WorkspaceWindowEntry {
  WorkspaceWindowEntry({
    required this.id,
    required this.title,
    required this.child,
    required this.rect,
    this.subtitle = '',
    this.iconKind = SportotekaWorkspaceIconKind.document,
    this.minimized = false,
    this.snap = WorkspaceWindowSnap.none,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  final String id;
  final String title;
  final String subtitle;
  final SportotekaWorkspaceIconKind iconKind;
  final Widget child;
  final Rect rect;
  final bool minimized;
  final WorkspaceWindowSnap snap;
  final GlobalKey<NavigatorState> navigatorKey;

  WorkspaceWindowEntry copyWith({
    String? title,
    String? subtitle,
    SportotekaWorkspaceIconKind? iconKind,
    Widget? child,
    Rect? rect,
    bool? minimized,
    WorkspaceWindowSnap? snap,
  }) {
    return WorkspaceWindowEntry(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconKind: iconKind ?? this.iconKind,
      child: child ?? this.child,
      rect: rect ?? this.rect,
      minimized: minimized ?? this.minimized,
      snap: snap ?? this.snap,
      navigatorKey: navigatorKey,
    );
  }
}

class WorkspaceWindowLayer extends StatelessWidget {
  const WorkspaceWindowLayer({
    super.key,
    required this.entries,
    required this.activeId,
    required this.onActivate,
    required this.onClose,
    required this.onMove,
    required this.onResize,
    required this.onMinimize,
    required this.onRestore,
    required this.onSnap,
  });

  final List<WorkspaceWindowEntry> entries;
  final String? activeId;
  final ValueChanged<String> onActivate;
  final ValueChanged<String> onClose;
  final void Function(String id, Offset delta) onMove;
  final void Function(String id, Offset delta) onResize;
  final ValueChanged<String> onMinimize;
  final ValueChanged<String> onRestore;
  final void Function(String id, WorkspaceWindowSnap snap) onSnap;

  static const _line = Color(0xFFE5E8E5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _green = Color(0xFF0B8F55);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        final visible = entries.where((entry) => !entry.minimized).toList(growable: false);
        final minimized = entries.where((entry) => entry.minimized).toList(growable: false);
        return IgnorePointer(
          ignoring: entries.isEmpty,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in visible)
                _WorkspaceFloatingWindow(
                  key: ValueKey('workspace-window-${entry.id}'),
                  entry: entry,
                  bounds: bounds,
                  active: entry.id == activeId,
                  onActivate: () => onActivate(entry.id),
                  onClose: () => onClose(entry.id),
                  onMove: (delta) => onMove(entry.id, delta),
                  onResize: (delta) => onResize(entry.id, delta),
                  onMinimize: () => onMinimize(entry.id),
                  onSnap: (snap) => onSnap(entry.id, snap),
                ),
              if (entries.length > 1 || minimized.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 920),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 18, offset: Offset(0, 7))],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Material(
                                  color: entry.id == activeId && !entry.minimized ? const Color(0xFFEAF5EF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => entry.minimized ? onRestore(entry.id) : onActivate(entry.id),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SportotekaWorkspaceIcon(kind: entry.iconKind, size: 17, color: entry.id == activeId ? _green : _muted),
                                          const SizedBox(width: 7),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 180),
                                            child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuTitle(color: _text)),
                                          ),
                                          if (entry.minimized) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.remove_rounded, size: 13, color: _muted),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceFloatingWindow extends StatelessWidget {
  const _WorkspaceFloatingWindow({
    super.key,
    required this.entry,
    required this.bounds,
    required this.active,
    required this.onActivate,
    required this.onClose,
    required this.onMove,
    required this.onResize,
    required this.onMinimize,
    required this.onSnap,
  });

  final WorkspaceWindowEntry entry;
  final Size bounds;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;
  final VoidCallback onMinimize;
  final ValueChanged<WorkspaceWindowSnap> onSnap;

  static const _line = Color(0xFFE5E8E5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _green = Color(0xFF0B8F55);

  Rect _resolvedRect() {
    const gap = 10.0;
    switch (entry.snap) {
      case WorkspaceWindowSnap.left:
        return Rect.fromLTWH(gap, gap, math.max(360.0, bounds.width / 2 - gap * 1.5), math.max(360.0, bounds.height - gap * 2));
      case WorkspaceWindowSnap.right:
        final width = math.max(360.0, bounds.width / 2 - gap * 1.5);
        return Rect.fromLTWH(bounds.width - width - gap, gap, width, math.max(360.0, bounds.height - gap * 2));
      case WorkspaceWindowSnap.maximized:
        return Rect.fromLTWH(gap, gap, math.max(360.0, bounds.width - gap * 2), math.max(360.0, bounds.height - gap * 2));
      case WorkspaceWindowSnap.none:
        final minWidth = math.min(520.0, math.max(320.0, bounds.width - gap * 2));
        final minHeight = math.min(420.0, math.max(300.0, bounds.height - gap * 2));
        final width = entry.rect.width.clamp(minWidth, math.max(minWidth, bounds.width - gap * 2)).toDouble();
        final height = entry.rect.height.clamp(minHeight, math.max(minHeight, bounds.height - gap * 2)).toDouble();
        final maxLeft = math.max(gap, bounds.width - width - gap);
        final maxTop = math.max(gap, bounds.height - height - gap);
        return Rect.fromLTWH(
          entry.rect.left.clamp(gap, maxLeft).toDouble(),
          entry.rect.top.clamp(gap, maxTop).toDouble(),
          width,
          height,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = _resolvedRect();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Listener(
        onPointerDown: (_) => onActivate(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: active ? const Color(0xFFCADDD2) : _line),
            boxShadow: [
              BoxShadow(
                color: active ? const Color(0x24000000) : const Color(0x14000000),
                blurRadius: active ? 28 : 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => onSnap(entry.snap == WorkspaceWindowSnap.maximized ? WorkspaceWindowSnap.none : WorkspaceWindowSnap.maximized),
                onPanUpdate: entry.snap == WorkspaceWindowSnap.none ? (details) => onMove(details.delta) : null,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _line))),
                  child: Row(
                    children: [
                      _WindowDot(color: const Color(0xFFE56A67), onTap: onClose),
                      const SizedBox(width: 6),
                      _WindowDot(color: const Color(0xFFE4B64C), onTap: onMinimize),
                      const SizedBox(width: 6),
                      _WindowDot(
                        color: const Color(0xFF65B985),
                        onTap: () => onSnap(entry.snap == WorkspaceWindowSnap.maximized ? WorkspaceWindowSnap.none : WorkspaceWindowSnap.maximized),
                      ),
                      const SizedBox(width: 12),
                      SportotekaWorkspaceIcon(kind: entry.iconKind, size: 17, color: _green),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuTitle(color: _text))),
                            if (entry.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Flexible(child: Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted))),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<WorkspaceWindowSnap>(
                        tooltip: 'Размещение окна',
                        color: Colors.white,
                        onSelected: onSnap,
                        itemBuilder: (_) => <PopupMenuEntry<WorkspaceWindowSnap>>[
                          PopupMenuItem(value: WorkspaceWindowSnap.left, child: Text('Слева', style: AppTypography.menuTitle())),
                          PopupMenuItem(value: WorkspaceWindowSnap.right, child: Text('Справа', style: AppTypography.menuTitle())),
                          PopupMenuItem(value: WorkspaceWindowSnap.maximized, child: Text('На весь Workspace', style: AppTypography.menuTitle())),
                          PopupMenuItem(value: WorkspaceWindowSnap.none, child: Text('Свободное окно', style: AppTypography.menuTitle())),
                        ],
                        icon: const Icon(Icons.grid_view_rounded, size: 17, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Navigator(
                  key: entry.navigatorKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => ColoredBox(color: Colors.white, child: entry.child),
                  ),
                ),
              ),
              if (entry.snap == WorkspaceWindowSnap.none)
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => onResize(details.delta),
                    child: const SizedBox(
                      width: 24,
                      height: 18,
                      child: Align(
                        alignment: Alignment.center,
                        child: Icon(Icons.drag_handle_rounded, size: 15, color: Color(0xFFA3ABA5)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 14,
          height: 20,
          child: Center(child: Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
        ),
      );
}
