import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
  });

  final String id;
  final String title;
  final String subtitle;
  final SportotekaWorkspaceIconKind iconKind;
  final Widget child;
  final Rect rect;
  final bool minimized;
  final WorkspaceWindowSnap snap;

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
        final media = MediaQuery.of(context);
        final safeTop = media.viewPadding.top;
        final safeBottom =
            math.max(media.viewPadding.bottom, media.padding.bottom);
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        final visible =
            entries.where((entry) => !entry.minimized).toList(growable: false);
        final minimized =
            entries.where((entry) => entry.minimized).toList(growable: false);
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
                  safeTop: safeTop,
                  safeBottom: safeBottom,
                ),
              if (entries.length > 1 || minimized.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10 + safeBottom,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 920),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 18,
                              offset: Offset(0, 7))
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in entries)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Material(
                                  color:
                                      entry.id == activeId && !entry.minimized
                                          ? const Color(0xFFEAF5EF)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => entry.minimized
                                        ? onRestore(entry.id)
                                        : onActivate(entry.id),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 7),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SportotekaWorkspaceIcon(
                                              kind: entry.iconKind,
                                              size: 17,
                                              color: entry.id == activeId
                                                  ? _green
                                                  : _muted),
                                          const SizedBox(width: 7),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: 180),
                                            child: Text(entry.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.menuTitle(
                                                    color: _text)),
                                          ),
                                          if (entry.minimized) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.remove_rounded,
                                                size: 13, color: _muted),
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
    required this.safeTop,
    required this.safeBottom,
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
  final double safeTop;
  final double safeBottom;

  static const _line = Color(0xFFE5E8E5);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _green = Color(0xFF0B8F55);

  Rect _resolvedRect() {
    const gap = 10.0;
    final topInset = safeTop > 0 ? safeTop + gap : gap;
    final bottomInset = safeBottom > 0 ? safeBottom + gap : gap;
    switch (entry.snap) {
      case WorkspaceWindowSnap.left:
        return Rect.fromLTWH(
          gap,
          topInset,
          math.max(360.0, bounds.width / 2 - gap * 1.5),
          math.max(360.0, bounds.height - topInset - bottomInset),
        );
      case WorkspaceWindowSnap.right:
        final width = math.max(360.0, bounds.width / 2 - gap * 1.5);
        return Rect.fromLTWH(
          bounds.width - width - gap,
          topInset,
          width,
          math.max(360.0, bounds.height - topInset - bottomInset),
        );
      case WorkspaceWindowSnap.maximized:
        return Rect.fromLTWH(
          gap,
          topInset,
          math.max(360.0, bounds.width - gap * 2),
          math.max(360.0, bounds.height - topInset - bottomInset),
        );
      case WorkspaceWindowSnap.none:
        final maxWidth = math.max(360.0, bounds.width - gap * 2);
        final maxHeight =
            math.max(360.0, bounds.height - topInset - bottomInset);
        final width = entry.rect.width.clamp(360.0, maxWidth).toDouble();
        final height = entry.rect.height.clamp(360.0, maxHeight).toDouble();
        final maxTop = math.max(topInset, bounds.height - height - bottomInset);
        return Rect.fromLTWH(
          entry.rect.left
              .clamp(gap, math.max(gap, bounds.width - width - gap))
              .toDouble(),
          entry.rect.top.clamp(topInset, maxTop).toDouble(),
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
            boxShadow: [
              BoxShadow(
                color:
                    active ? const Color(0x24000000) : const Color(0x14000000),
                blurRadius: active ? 28 : 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => onSnap(
                    entry.snap == WorkspaceWindowSnap.maximized
                        ? WorkspaceWindowSnap.none
                        : WorkspaceWindowSnap.maximized),
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (_) {
                    if (entry.snap != WorkspaceWindowSnap.none) {
                      onSnap(WorkspaceWindowSnap.none);
                    }
                  },
                  onPanUpdate: (details) => onMove(details.delta),
                  child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: _line))),
                  child: Row(
                    children: [
                      _WindowControl(
                        icon: Icons.close_rounded,
                        tooltip: 'Закрыть',
                        onTap: onClose,
                      ),
                      const SizedBox(width: 6),
                      _WindowControl(
                        icon: Icons.remove_rounded,
                        tooltip: 'Свернуть',
                        onTap: onMinimize,
                      ),
                      const SizedBox(width: 6),
                      _WindowControl(
                        icon: Icons.zoom_out_map_rounded,
                        tooltip: entry.snap == WorkspaceWindowSnap.maximized
                            ? 'Вернуть размер'
                            : 'Развернуть',
                        onTap: () => onSnap(
                          entry.snap == WorkspaceWindowSnap.maximized
                              ? WorkspaceWindowSnap.none
                              : WorkspaceWindowSnap.maximized,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SportotekaWorkspaceIcon(
                          kind: entry.iconKind, size: 17, color: _green),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                                child: Text(entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.menuTitle(color: _text))),
                            if (entry.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Flexible(
                                  child: Text(entry.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption(
                                          color: _muted))),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<WorkspaceWindowSnap>(
                        tooltip: 'Размещение окна',
                        color: Colors.white,
                        onSelected: onSnap,
                        itemBuilder: (_) =>
                            <PopupMenuEntry<WorkspaceWindowSnap>>[
                          PopupMenuItem(
                              value: WorkspaceWindowSnap.left,
                              child: Text('Слева',
                                  style: AppTypography.menuTitle())),
                          PopupMenuItem(
                              value: WorkspaceWindowSnap.right,
                              child: Text('Справа',
                                  style: AppTypography.menuTitle())),
                          PopupMenuItem(
                              value: WorkspaceWindowSnap.maximized,
                              child: Text('На весь Workspace',
                                  style: AppTypography.menuTitle())),
                          PopupMenuItem(
                              value: WorkspaceWindowSnap.none,
                              child: Text('Свободное окно',
                                  style: AppTypography.menuTitle())),
                        ],
                        icon: const Icon(Icons.grid_view_rounded,
                            size: 17, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) =>
                        ColoredBox(color: Colors.white, child: entry.child),
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
                        child: Icon(Icons.drag_handle_rounded,
                            size: 15, color: Color(0xFFA3ABA5)),
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

class _WindowControl extends StatelessWidget {
  const _WindowControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F3F5),
          ),
          child: Icon(
            icon,
            size: 10,
            color: const Color(0xFF667085),
          ),
        ),
      ),
    );
  }
}

/// Opens any external Sportoteka surface inside the same floating-window
/// chrome used by Workspace OS. Calendar, plans and documents can call this
/// instead of inventing their own Overlay window implementation.
Future<void> showWorkspaceManagedWindow(
  BuildContext context, {
  required String id,
  required String title,
  String subtitle = '',
  SportotekaWorkspaceIconKind iconKind = SportotekaWorkspaceIconKind.document,
  Size preferredSize = const Size(920, 680),
  required Widget Function(VoidCallback closeWindow) builder,
}) async {
  final media = MediaQuery.of(context);
  if (media.size.width < 760) {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: builder(() => Navigator.of(routeContext).maybePop()),
          ),
        ),
      ),
    );
    return;
  }

  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry overlayEntry;
  var closed = false;

  void closeWindow() {
    if (closed) return;
    closed = true;
    if (overlayEntry.mounted) overlayEntry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  overlayEntry = OverlayEntry(
    builder: (_) => _WorkspaceStandaloneWindowHost(
      id: id,
      title: title,
      subtitle: subtitle,
      iconKind: iconKind,
      preferredSize: preferredSize,
      onClose: closeWindow,
      builder: builder,
    ),
  );
  overlay.insert(overlayEntry);
  await completer.future;
}

class _WorkspaceStandaloneWindowHost extends StatefulWidget {
  const _WorkspaceStandaloneWindowHost({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKind,
    required this.preferredSize,
    required this.onClose,
    required this.builder,
  });

  final String id;
  final String title;
  final String subtitle;
  final SportotekaWorkspaceIconKind iconKind;
  final Size preferredSize;
  final VoidCallback onClose;
  final Widget Function(VoidCallback closeWindow) builder;

  @override
  State<_WorkspaceStandaloneWindowHost> createState() =>
      _WorkspaceStandaloneWindowHostState();
}

class _WorkspaceStandaloneWindowHostState
    extends State<_WorkspaceStandaloneWindowHost> {
  late Rect _rect;
  WorkspaceWindowSnap _snap = WorkspaceWindowSnap.none;
  bool _minimized = false;
  bool _initialized = false;
  late final Widget _child;

  @override
  void initState() {
    super.initState();
    _child = widget.builder(widget.onClose);
    _rect = Rect.fromLTWH(
      36,
      48,
      widget.preferredSize.width,
      widget.preferredSize.height,
    );
  }

  void _ensureInitialRect(Size bounds, EdgeInsets padding) {
    if (_initialized) return;
    const gap = 12.0;
    final safeWidth = math.max(360.0, bounds.width - gap * 2);
    final safeHeight = math.max(
      360.0,
      bounds.height - padding.top - padding.bottom - gap * 2,
    );
    final width = widget.preferredSize.width.clamp(520.0, safeWidth).toDouble();
    final height = widget.preferredSize.height.clamp(420.0, safeHeight).toDouble();
    final left = math.max(gap, (bounds.width - width) / 2);
    final top = math.max(padding.top + gap, (bounds.height - height) / 2);
    _rect = Rect.fromLTWH(left, top, width, height);
    _initialized = true;
  }

  void _move(Offset delta) {
    final size = MediaQuery.sizeOf(context);
    const gap = 10.0;
    final shifted = _rect.shift(delta);
    final maxLeft = math.max(gap, size.width - _rect.width - gap);
    final maxTop = math.max(gap, size.height - _rect.height - gap);
    setState(() {
      _rect = Rect.fromLTWH(
        shifted.left.clamp(gap, maxLeft).toDouble(),
        shifted.top.clamp(gap, maxTop).toDouble(),
        _rect.width,
        _rect.height,
      );
      _snap = WorkspaceWindowSnap.none;
    });
  }

  void _resize(Offset delta) {
    final size = MediaQuery.sizeOf(context);
    final width = (_rect.width + delta.dx)
        .clamp(520.0, math.max(520.0, size.width - _rect.left - 10))
        .toDouble();
    final height = (_rect.height + delta.dy)
        .clamp(420.0, math.max(420.0, size.height - _rect.top - 10))
        .toDouble();
    setState(() {
      _rect = Rect.fromLTWH(_rect.left, _rect.top, width, height);
      _snap = WorkspaceWindowSnap.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounds = Size(constraints.maxWidth, constraints.maxHeight);
          _ensureInitialRect(bounds, media.padding);

          if (_minimized) {
            return Stack(
              children: [
                Positioned(
                  left: 18,
                  bottom: 18 + media.padding.bottom,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    elevation: 8,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => setState(() => _minimized = false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SportotekaWorkspaceIcon(
                              kind: widget.iconKind,
                              size: 17,
                              color: const Color(0xFF0B8F55),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.menuTitle(
                                  color: const Color(0xFF101814),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.open_in_full_rounded,
                              size: 14,
                              color: Color(0xFF758079),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final entry = WorkspaceWindowEntry(
            id: widget.id,
            title: widget.title,
            subtitle: widget.subtitle,
            iconKind: widget.iconKind,
            child: _child,
            rect: _rect,
            snap: _snap,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              _WorkspaceFloatingWindow(
                entry: entry,
                bounds: bounds,
                active: true,
                onActivate: () {},
                onClose: widget.onClose,
                onMove: _move,
                onResize: _resize,
                onMinimize: () => setState(() => _minimized = true),
                onSnap: (snap) => setState(() => _snap = snap),
                safeTop: media.viewPadding.top,
                safeBottom: math.max(
                  media.viewPadding.bottom,
                  media.padding.bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
