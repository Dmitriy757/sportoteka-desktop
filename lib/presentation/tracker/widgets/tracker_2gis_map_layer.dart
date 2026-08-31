import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/tracker_pro_models.dart';
import 'tracker_2gis_local_key.dart';

/// Подложка карты для Live и архива. Поле остаётся штатным Flutter-слоем,
/// 2ГИС и спутник отображаются через один MapGL WebView на iOS/macOS.
enum TrackerGeoBaseLayer { pitch, dgis, satellite }

extension TrackerGeoBaseLayerUi on TrackerGeoBaseLayer {
  String get label {
    switch (this) {
      case TrackerGeoBaseLayer.pitch:
        return 'Поле';
      case TrackerGeoBaseLayer.dgis:
        return 'Карта';
      case TrackerGeoBaseLayer.satellite:
        return 'Спутник';
    }
  }

  IconData get icon {
    switch (this) {
      case TrackerGeoBaseLayer.pitch:
        return Icons.sports_soccer_rounded;
      case TrackerGeoBaseLayer.dgis:
        return Icons.map_rounded;
      case TrackerGeoBaseLayer.satellite:
        return Icons.satellite_alt_rounded;
    }
  }
}

class TrackerGeoPoint {
  const TrackerGeoPoint({
    required this.latitude,
    required this.longitude,
    required this.timeMs,
    this.speedKmh = 0,
    this.breakBefore = false,
  });

  final double latitude;
  final double longitude;
  final int timeMs;
  final double speedKmh;
  final bool breakBefore;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lon': longitude,
        'time_ms': timeMs,
        'speed_kmh': speedKmh.isFinite ? speedKmh : 0,
        if (breakBefore) 'break_before': true,
      };
}

class TrackerGeoTrack {
  const TrackerGeoTrack({
    required this.id,
    required this.name,
    required this.points,
    this.avatar,
    this.color = const Color(0xFF16794B),
    this.selected = false,
  });

  final String id;
  final String name;
  final String? avatar;
  final Color color;
  final bool selected;
  final List<TrackerGeoPoint> points;

  Map<String, dynamic> toJson({
    int? cursorTimeMs,
    int? routeWindowMs,
  }) {
    final valid = points.where((point) => point.isValid).toList(growable: false);
    final routeEndMs = cursorTimeMs != null && cursorTimeMs > 0
        ? cursorTimeMs
        : (valid.isEmpty ? 0 : valid.last.timeMs);
    final routeSource = routeWindowMs != null &&
            routeWindowMs > 0 &&
            routeEndMs > 0
        ? valid
            .where(
              (point) =>
                  point.timeMs <= routeEndMs &&
                  point.timeMs >= routeEndMs - routeWindowMs,
            )
            .toList(growable: false)
        : valid;
    final route = _downsample(routeSource, 720);
    TrackerGeoPoint? current;
    if (valid.isNotEmpty) {
      if (cursorTimeMs == null || cursorTimeMs <= 0) {
        current = valid.last;
      } else {
        TrackerGeoPoint? previous;
        TrackerGeoPoint? next;
        for (final point in valid) {
          if (point.timeMs <= cursorTimeMs) {
            previous = point;
          } else {
            next = point;
            break;
          }
        }
        final base = previous ?? valid.first;
        current = base;
        // Replay: положение на 2ГИС/спутнике вычисляем внутри GPS-сегмента,
        // а не прыгаем только по сохранённым точкам. На больших разрывах связи
        // остаёмся на последней подтверждённой позиции.
        if (next != null && next.timeMs > base.timeMs && !next.breakBefore) {
          final gapMs = next.timeMs - base.timeMs;
          if (gapMs <= 15000 &&
              cursorTimeMs >= base.timeMs &&
              cursorTimeMs <= next.timeMs) {
            final ratio = ((cursorTimeMs - base.timeMs) / gapMs)
                .clamp(0.0, 1.0)
                .toDouble();
            current = TrackerGeoPoint(
              latitude: base.latitude + (next.latitude - base.latitude) * ratio,
              longitude:
                  base.longitude + (next.longitude - base.longitude) * ratio,
              timeMs: cursorTimeMs,
              speedKmh: base.speedKmh + (next.speedKmh - base.speedKmh) * ratio,
            );
          }
        }
      }
    }
    return <String, dynamic>{
      'id': id,
      'name': name.trim().isEmpty ? 'Игрок' : name.trim(),
      'avatar': '${avatar ?? ''}'.trim(),
      'color': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      'selected': selected,
      'points': route.map((point) => point.toJson()).toList(growable: false),
      if (current != null) 'current': current.toJson(),
    };
  }

  static List<TrackerGeoPoint> _downsample(
    List<TrackerGeoPoint> source,
    int limit,
  ) {
    if (source.length <= limit) return source;
    final step = math.max(1, (source.length / limit).ceil());
    final result = <TrackerGeoPoint>[];
    for (var index = 0; index < source.length; index += step) {
      result.add(source[index]);
    }
    if (!identical(result.last, source.last)) result.add(source.last);
    return result;
  }
}

/// Компактный переключатель подложки. Одинаково используется в Live и архиве.
class TrackerGeoLayerSwitch extends StatelessWidget {
  const TrackerGeoLayerSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final TrackerGeoBaseLayer value;
  final ValueChanged<TrackerGeoBaseLayer> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = value != TrackerGeoBaseLayer.pitch;
    return PopupMenuButton<TrackerGeoBaseLayer>(
      tooltip: 'Подложка карты',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => TrackerGeoBaseLayer.values
          .map(
            (layer) => PopupMenuItem<TrackerGeoBaseLayer>(
              value: layer,
              child: Row(
                children: [
                  Icon(
                    layer.icon,
                    size: 18,
                    color: layer == value
                        ? const Color(0xFF16794B)
                        : const Color(0xFF56635D),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    layer.label,
                    style: TextStyle(
                      color: layer == value
                          ? const Color(0xFF16794B)
                          : const Color(0xFF26332D),
                      fontSize: 12,
                      fontWeight: layer == value
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  if (layer == value) ...[
                    const Spacer(),
                    const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: Color(0xFF16794B),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFEAF7EF)
              : Colors.white.withOpacity(.90),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? const Color(0xFF72B88F)
                : const Color(0xFFDDE5E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value.icon,
              size: 16,
              color: active
                  ? const Color(0xFF16794B)
                  : const Color(0xFF52615A),
            ),
            const SizedBox(width: 6),
            Text(
              compact ? value.label : 'Фон: ${value.label}',
              style: TextStyle(
                color: active
                    ? const Color(0xFF16794B)
                    : const Color(0xFF394740),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 17,
              color: Color(0xFF718079),
            ),
          ],
        ),
      ),
    );
  }
}

/// Всегда видимый переключатель подложки. В отличие от popup-меню его
/// невозможно «потерять» в Live: тренер сразу видит Поле / 2ГИС / Спутник.
class TrackerGeoLayerStrip extends StatelessWidget {
  const TrackerGeoLayerStrip({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.showPitch = true,
  });

  final TrackerGeoBaseLayer value;
  final ValueChanged<TrackerGeoBaseLayer> onChanged;
  final bool compact;
  final bool showPitch;

  @override
  Widget build(BuildContext context) {
    final layers = TrackerGeoBaseLayer.values
        .where((layer) => showPitch || layer != TrackerGeoBaseLayer.pitch)
        .toList(growable: false);
    return Material(
      color: Colors.white.withOpacity(.96),
      borderRadius: BorderRadius.circular(10),
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(.10),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < layers.length; index++) ...[
              if (index > 0) const SizedBox(width: 2),
              Builder(builder: (context) {
                final layer = layers[index];
                final active = layer == value;
                return InkWell(
                  onTap: () => onChanged(layer),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: compact ? 30 : 32,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 9,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFEAF7EF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          layer.icon,
                          size: compact ? 13 : 14,
                          color: active
                              ? const Color(0xFF16794B)
                              : const Color(0xFF64716B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          layer.label,
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF16794B)
                                : const Color(0xFF46534D),
                            fontSize: compact ? 8.8 : 9.4,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

enum _TrackerMapRotationAction { auto, left, right, north }

/// Поворот географической подложки. `null` означает автоматическое
/// выравнивание по длинной стороне откалиброванного поля (или по GPS-треку).
class TrackerMapRotationControl extends StatelessWidget {
  const TrackerMapRotationControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final double? value;
  final ValueChanged<double?> onChanged;
  final bool compact;

  static double _normalized(double value) {
    var result = value;
    while (result > 180) result -= 360;
    while (result <= -180) result += 360;
    return result;
  }

  void _select(_TrackerMapRotationAction action) {
    switch (action) {
      case _TrackerMapRotationAction.auto:
        onChanged(null);
        return;
      case _TrackerMapRotationAction.left:
        onChanged(_normalized((value ?? 0) - 5));
        return;
      case _TrackerMapRotationAction.right:
        onChanged(_normalized((value ?? 0) + 5));
        return;
      case _TrackerMapRotationAction.north:
        onChanged(0);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'Авто' : '${value!.round()}°';
    return PopupMenuButton<_TrackerMapRotationAction>(
      tooltip: 'Поворот карты',
      onSelected: _select,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _TrackerMapRotationAction.auto,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.crop_landscape_rounded, size: 19),
            title: Text('Выровнять по полю'),
          ),
        ),
        PopupMenuItem(
          value: _TrackerMapRotationAction.left,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.rotate_left_rounded, size: 19),
            title: Text('Повернуть влево на 5°'),
          ),
        ),
        PopupMenuItem(
          value: _TrackerMapRotationAction.right,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.rotate_right_rounded, size: 19),
            title: Text('Повернуть вправо на 5°'),
          ),
        ),
        PopupMenuItem(
          value: _TrackerMapRotationAction.north,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.navigation_rounded, size: 19),
            title: Text('Север сверху (0°)'),
          ),
        ),
      ],
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7EF),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF72B88F)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.screen_rotation_alt_rounded,
              size: 16,
              color: Color(0xFF16794B),
            ),
            const SizedBox(width: 6),
            Text(
              compact ? label : 'Поворот: $label',
              style: const TextStyle(
                color: Color(0xFF16794B),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 17,
              color: Color(0xFF718079),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выдвижной контрол прямо поверх карты: выбор подложки и круговой джойстик
/// поворота. Используется одинаково в Live и в архивной аналитике.
class TrackerGeoMapDock extends StatefulWidget {
  const TrackerGeoMapDock({
    super.key,
    required this.layer,
    required this.onLayerChanged,
    required this.rotationDeg,
    required this.onRotationChanged,
    this.showTrace,
    this.onShowTraceChanged,
    this.compact = false,
    this.expandUp = true,
    this.showPitch = true,
  });

  final TrackerGeoBaseLayer layer;
  final ValueChanged<TrackerGeoBaseLayer> onLayerChanged;
  final double? rotationDeg;
  final ValueChanged<double?> onRotationChanged;
  final bool? showTrace;
  final ValueChanged<bool>? onShowTraceChanged;
  final bool compact;
  final bool expandUp;
  final bool showPitch;

  @override
  State<TrackerGeoMapDock> createState() => _TrackerGeoMapDockState();
}

class _TrackerGeoMapDockState extends State<TrackerGeoMapDock> {
  bool _expanded = false;
  Offset _thumb = Offset.zero;

  double _normalized(double value) {
    var result = value;
    while (result > 180) result -= 360;
    while (result <= -180) result += 360;
    return result;
  }

  void _updateThumb(Offset local, double side) {
    final center = Offset(side / 2, side / 2);
    var delta = local - center;
    const maxRadius = 19.0;
    if (delta.distance > maxRadius) {
      delta = Offset.fromDirection(delta.direction, maxRadius);
    }
    setState(() => _thumb = delta);
  }

  void _rotate(DragUpdateDetails details) {
    _updateThumb(details.localPosition, 76);
    final current = widget.rotationDeg ?? 0;
    widget.onRotationChanged(_normalized(current + details.delta.dx * .55));
  }

  Widget _layerButton(TrackerGeoBaseLayer layer) {
    final active = widget.layer == layer;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onLayerChanged(layer),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE7F5EC) : const Color(0xFFF5F7F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF75B990)
                  : const Color(0xFFE1E7E3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                layer.icon,
                size: 17,
                color: active
                    ? const Color(0xFF16794B)
                    : const Color(0xFF64716B),
              ),
              const SizedBox(height: 3),
              Text(
                layer.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF16794B)
                      : const Color(0xFF46534D),
                  fontSize: 9.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orbitPad() {
    const side = 76.0;
    return Tooltip(
      message: 'Тяните влево или вправо для поворота карты. Двойное нажатие — авто.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => widget.onRotationChanged(null),
        onPanStart: (details) => _updateThumb(details.localPosition, side),
        onPanUpdate: _rotate,
        onPanEnd: (_) => setState(() => _thumb = Offset.zero),
        onPanCancel: () => setState(() => _thumb = Offset.zero),
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.97),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD9E2DD)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 12,
                spreadRadius: -4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 6,
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 17, color: Color(0xFF7A8781)),
              ),
              const Positioned(
                bottom: 6,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 17, color: Color(0xFF7A8781)),
              ),
              const Positioned(
                left: 6,
                child: Icon(Icons.keyboard_arrow_left_rounded,
                    size: 17, color: Color(0xFF7A8781)),
              ),
              const Positioned(
                right: 6,
                child: Icon(Icons.keyboard_arrow_right_rounded,
                    size: 17, color: Color(0xFF7A8781)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 65),
                transform: Matrix4.translationValues(_thumb.dx, _thumb.dy, 0),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF16794B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16794B).withOpacity(.25),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.open_with_rounded,
                    size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final geo = widget.layer != TrackerGeoBaseLayer.pitch;
    final rotationLabel = widget.rotationDeg == null
        ? 'Авто по GPS'
        : '${widget.rotationDeg!.round()}° от авто';
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.compact ? 238 : 258,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.97),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE5E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.15),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded,
                    size: 17, color: Color(0xFF16794B)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Карта',
                    style: TextStyle(
                      color: Color(0xFF26332D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.close_rounded,
                        size: 17, color: Color(0xFF66736D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.showPitch) ...[
                  _layerButton(TrackerGeoBaseLayer.pitch),
                  const SizedBox(width: 5),
                ],
                _layerButton(TrackerGeoBaseLayer.dgis),
                const SizedBox(width: 5),
                _layerButton(TrackerGeoBaseLayer.satellite),
              ],
            ),
            if (geo) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Поворот',
                          style: TextStyle(
                            color: Color(0xFF6C7973),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rotationLabel,
                          style: const TextStyle(
                            color: Color(0xFF26332D),
                            fontSize: 11.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        GestureDetector(
                          onTap: () => widget.onRotationChanged(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.rotationDeg == null
                                  ? const Color(0xFFE7F5EC)
                                  : const Color(0xFFF1F4F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Сбросить к GPS',
                              style: TextStyle(
                                color: Color(0xFF16794B),
                                fontSize: 9.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (widget.showTrace != null &&
                            widget.onShowTraceChanged != null) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => widget.onShowTraceChanged!(
                                !(widget.showTrace ?? false)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.showTrace == true
                                    ? const Color(0xFFE7F5EC)
                                    : const Color(0xFFF1F4F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.showTrace == true
                                    ? 'GPS-линии: вкл.'
                                    : 'GPS-линии: выкл.',
                                style: const TextStyle(
                                  color: Color(0xFF16794B),
                                  fontSize: 9.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _orbitPad(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toggleButton() {
    return Tooltip(
      message: _expanded ? 'Свернуть карту' : 'Карта и поворот',
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF16794B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.20),
                  blurRadius: 13,
                  spreadRadius: -4,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              _expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : widget.layer.icon,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expandedChildren = widget.expandUp
        ? <Widget>[_panel(), const SizedBox(height: 7), _toggleButton()]
        : <Widget>[_toggleButton(), const SizedBox(height: 7), _panel()];
    return AnimatedSize(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: _expanded ? expandedChildren : <Widget>[_toggleButton()],
      ),
    );
  }
}

class Tracker2GisMapLayer extends StatefulWidget {
  const Tracker2GisMapLayer({
    super.key,
    required this.layer,
    required this.tracks,
    this.cursorTimeMs,
    this.live = false,
    this.followLatest = false,
    this.interactive = true,
    this.perspective3d = false,
    this.field,
    this.rotationDeg,
    this.showPlayers = true,
    this.showLabels = true,
    this.showTrace = true,
    this.routeWindowMs,
    this.smoothPlayerMotion = false,
    this.playerMotionDurationMs = 220,
    this.calibrationEnabled = false,
    this.calibrationRectangleMode = false,
    this.calibrationCorners = const <TrackerGeoPoint>[],
    this.calibrationEditingIndex,
    this.initialCenter,
    this.onCalibrationCornersChanged,
    this.onCalibrationCornerSelected,
  }) : assert(layer != TrackerGeoBaseLayer.pitch);

  final TrackerGeoBaseLayer layer;
  final List<TrackerGeoTrack> tracks;
  final int? cursorTimeMs;
  final bool live;
  final bool followLatest;
  final bool interactive;
  final bool perspective3d;
  final TrackerFieldModel? field;
  final double? rotationDeg;
  final bool showPlayers;
  final bool showLabels;
  final bool showTrace;
  final int? routeWindowMs;
  /// Плавное визуальное перемещение архивных/Replay-маркеров между
  /// обновлениями курсора. Live включает сглаживание независимо от этого флага.
  final bool smoothPlayerMotion;
  final int playerMotionDurationMs;
  final bool calibrationEnabled;
  final bool calibrationRectangleMode;
  final List<TrackerGeoPoint> calibrationCorners;
  final int? calibrationEditingIndex;
  final TrackerGeoPoint? initialCenter;
  final ValueChanged<List<TrackerGeoPoint>>? onCalibrationCornersChanged;
  final ValueChanged<int?>? onCalibrationCornerSelected;

  static const String _buildMapGlKey =
      String.fromEnvironment('DGIS_MAPGL_KEY', defaultValue: '');
  static String get mapGlKey => _buildMapGlKey.trim().isNotEmpty
      ? _buildMapGlKey.trim()
      : tracker2GisLocalMapGlKey.trim();
  static const String _buildSatelliteTileUrl =
      String.fromEnvironment('DGIS_SATELLITE_URL', defaultValue: '');
  static String get satelliteTileUrl {
    var value = _buildSatelliteTileUrl.trim().isNotEmpty
        ? _buildSatelliteTileUrl.trim()
        : trackerSatelliteTileUrl.trim();
    // MapTiler отдаёт HiDPI-тайл 512×512 для того же участка карты. Leaflet
    // показывает его в логических 256×256, поэтому снимок на Retina не мылится.
    if (value.contains('api.maptiler.com/maps/') && !value.contains('@2x.')) {
      value = value
          .replaceFirst('.jpg?', '@2x.jpg?')
          .replaceFirst('.png?', '@2x.png?')
          .replaceFirst('.webp?', '@2x.webp?');
    }
    return value;
  }
  static const String _buildSatelliteAttribution = String.fromEnvironment(
    'DGIS_SATELLITE_ATTRIBUTION',
    defaultValue: '',
  );
  static String get satelliteAttribution =>
      _buildSatelliteAttribution.trim().isNotEmpty
          ? _buildSatelliteAttribution.trim()
          : (trackerSatelliteAttribution.trim().isNotEmpty
              ? trackerSatelliteAttribution.trim()
              : 'Поставщик спутниковых снимков');

  static bool get hasMapKey => mapGlKey.isNotEmpty;
  static bool get hasSatelliteSource => satelliteTileUrl.trim().isNotEmpty;

  @override
  State<Tracker2GisMapLayer> createState() => _Tracker2GisMapLayerState();
}

class _Tracker2GisMapLayerState extends State<Tracker2GisMapLayer> {
  late final WebViewController _controller;
  Timer? _updateTimer;
  bool _mapReady = false;
  bool _pageLoading = true;
  String? _error;
  String _lastPayload = '';

  void _handleMapMessage(JavaScriptMessage message) {
    final raw = message.message.trim();
    if (!mounted) return;
    if (raw == 'ready') {
      setState(() {
        _mapReady = true;
        _pageLoading = false;
        _error = null;
      });
      _scheduleUpdate(immediate: true);
      return;
    }
    if (raw.startsWith('calibration:')) {
      try {
        final decoded = jsonDecode(raw.substring('calibration:'.length));
        if (decoded is! List) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        final points = <TrackerGeoPoint>[];
        for (final value in decoded.take(4)) {
          if (value is! List || value.length < 2) continue;
          final longitude = (value[0] as num?)?.toDouble();
          final latitude = (value[1] as num?)?.toDouble();
          if (longitude == null || latitude == null) continue;
          final point = TrackerGeoPoint(
            latitude: latitude,
            longitude: longitude,
            timeMs: now,
          );
          if (point.isValid) points.add(point);
        }
        widget.onCalibrationCornersChanged?.call(points);
      } catch (_) {
        // Неверный промежуточный пакет разметки не должен закрывать карту.
      }
      return;
    }
    if (raw.startsWith('calibration-select:')) {
      final index = int.tryParse(raw.substring('calibration-select:'.length));
      widget.onCalibrationCornerSelected
          ?.call(index != null && index >= 0 && index < 4 ? index : null);
      return;
    }
    if (raw.startsWith('error:')) {
      setState(() {
        _pageLoading = false;
        _error = raw.substring(6).trim().isEmpty
            ? 'Ошибка карты'
            : raw.substring(6).trim();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (!Tracker2GisMapLayer.hasMapKey) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _pageLoading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _pageLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _pageLoading = false;
              _error = 'Не удалось загрузить карту';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            final host = uri.host.toLowerCase();
            if (host == '2gis.com' || host.endsWith('.2gis.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'SportotekaMap',
        onMessageReceived: _handleMapMessage,
      );
    unawaited(_loadMap());
  }

  @override
  void didUpdateWidget(covariant Tracker2GisMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Tracker2GisMapLayer.hasMapKey) return;
    if (oldWidget.layer != widget.layer) {
      _mapReady = false;
      _lastPayload = '';
      unawaited(_loadMap());
      return;
    }
    _scheduleUpdate();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMap() async {
    if (!Tracker2GisMapLayer.hasMapKey) return;
    try {
      await _controller.loadHtmlString(
        _mapHtml(),
        baseUrl: 'https://mapgl.2gis.com/',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _error = 'Не удалось открыть слой карты';
      });
    }
  }

  void _scheduleUpdate({bool immediate = false}) {
    _updateTimer?.cancel();
    if (immediate) {
      unawaited(_sendUpdate());
      return;
    }
    // Live может обновляться чаще кадров карты. Один пакет раз в 160 мс
    // сохраняет плавность интерфейса и не меняет исходный сбор GPS.
    _updateTimer = Timer(const Duration(milliseconds: 160), () {
      unawaited(_sendUpdate());
    });
  }

  Future<void> _sendUpdate() async {
    if (!_mapReady || !Tracker2GisMapLayer.hasMapKey) return;
    final calibratedField = widget.field;
    final fieldCorners = calibratedField != null && calibratedField.hasCalibration
        ? <List<double>>[
            <double>[calibratedField.cornerALng!, calibratedField.cornerALat!],
            <double>[calibratedField.cornerBLng!, calibratedField.cornerBLat!],
            <double>[calibratedField.cornerCLng!, calibratedField.cornerCLat!],
            <double>[calibratedField.cornerDLng!, calibratedField.cornerDLat!],
          ]
        : const <List<double>>[];
    // Для угла карты передаём редкую выборку всей тренировки, а не только
    // 30-секундный хвост маршрута. Так спутник выравнивается по фактической
    // геометрии GPS, даже если сохранённая калибровка относится к соседнему полю.
    final orientationPoints = <List<double>>[];
    for (final track in widget.tracks) {
      final valid = track.points.where((point) => point.isValid).toList(growable: false);
      if (valid.isEmpty) continue;
      final step = math.max(1, (valid.length / 120).ceil());
      for (var index = 0; index < valid.length; index += step) {
        final point = valid[index];
        orientationPoints.add(<double>[point.longitude, point.latitude]);
      }
      final last = valid.last;
      if (orientationPoints.isEmpty ||
          orientationPoints.last[0] != last.longitude ||
          orientationPoints.last[1] != last.latitude) {
        orientationPoints.add(<double>[last.longitude, last.latitude]);
      }
    }
    final calibrationCorners = widget.calibrationCorners
        .where((point) => point.isValid)
        .take(4)
        .map((point) => <double>[point.longitude, point.latitude])
        .toList(growable: false);
    final initialCenter = widget.initialCenter?.isValid == true
        ? <double>[
            widget.initialCenter!.longitude,
            widget.initialCenter!.latitude,
          ]
        : null;
    final payload = jsonEncode(<String, dynamic>{
      'tracks': widget.tracks
          .map(
            (track) => track.toJson(
              cursorTimeMs: widget.cursorTimeMs,
              routeWindowMs: widget.routeWindowMs,
            ),
          )
          .toList(growable: false),
      'live': widget.live,
      'smooth_player_motion': widget.smoothPlayerMotion,
      'player_motion_duration_ms': widget.live
          ? 780
          : widget.playerMotionDurationMs.clamp(80, 1200),
      'follow': widget.followLatest,
      'interactive': widget.interactive,
      'pitch': widget.perspective3d ? 48 : 0,
      'rotation_deg': widget.rotationDeg,
      'orientation_points': orientationPoints,
      // Стабильный идентификатор выбранного архива. Он не зависит от позиции
      // ползунка повтора, но меняется при выборе другой тренировки/набора GPS.
      'dataset_key': '${widget.tracks.map((track) {
        final points = track.points;
        if (points.isEmpty) return '${track.id}:0';
        final first = points.first;
        final last = points.last;
        return '${track.id}:${points.length}:${first.timeMs}:'
            '${first.latitude}:${first.longitude}:${last.timeMs}:'
            '${last.latitude}:${last.longitude}';
      }).join('|')}|field:${fieldCorners.join(';')}',
      'field_corners': fieldCorners,
      'calibration_enabled': widget.calibrationEnabled,
      'calibration_mode':
          widget.calibrationRectangleMode ? 'rectangle' : 'points',
      'calibration_corners': calibrationCorners,
      'calibration_editing_index': widget.calibrationEditingIndex,
      'initial_center': initialCenter,
      'show_players': widget.showPlayers,
      'show_labels': widget.showLabels,
      'show_trace': widget.showTrace,
    });
    if (payload == _lastPayload) return;
    _lastPayload = payload;
    try {
      await _controller.runJavaScript(
        'window.sportotekaUpdate(${jsonEncode(payload)});',
      );
    } catch (_) {
      // При быстрой смене экрана WKWebView может завершиться раньше Future.
      // Следующий didUpdateWidget отправит актуальный кадр заново.
    }
  }

  String _mapHtml() {
    final config = jsonEncode(<String, dynamic>{
      'key': Tracker2GisMapLayer.mapGlKey.trim(),
      'satellite': widget.layer == TrackerGeoBaseLayer.satellite,
      'satellite_url': Tracker2GisMapLayer.satelliteTileUrl.trim(),
      'satellite_attribution':
          Tracker2GisMapLayer.satelliteAttribution.trim(),
    });
    return '''<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    html, body, #map { width:100%; height:100%; margin:0; overflow:hidden; background:#eef2ef; }
    * { box-sizing:border-box; }
    .leaflet-container { background:#eef2ef; font-family:-apple-system, BlinkMacSystemFont, sans-serif; }
    .leaflet-control-rotate { display:none !important; }
    .leaflet-player-icon { background:transparent !important; border:0 !important; overflow:visible !important; }
    .player { transform:translate(-17px, -17px); display:flex; align-items:center; gap:6px; pointer-events:none; width:max-content; min-height:34px; }
    .player.selected { transform:translate(-20px, -20px); min-height:40px; }
    .leaflet-player-icon .player { width:max-content; min-height:40px; transform:none; overflow:visible; }
    .leaflet-player-icon .player:not(.selected) .player-dot { margin:3px; }
    .player-dot { position:relative; width:34px; height:34px; border:3px solid #fff; border-radius:50%; background:#16794b; color:#fff; display:flex; align-items:center; justify-content:center; overflow:hidden; box-shadow:0 3px 12px rgba(16,45,31,.30); font:800 11px -apple-system, BlinkMacSystemFont, sans-serif; }
    .player.selected .player-dot { width:40px; height:40px; border-color:#bce7ca; box-shadow:0 0 0 3px rgba(22,121,75,.35), 0 4px 15px rgba(16,45,31,.34); }
    .player-dot img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
    .player-label { max-width:150px; padding:5px 8px; border-radius:8px; background:rgba(255,255,255,.94); color:#203229; box-shadow:0 2px 9px rgba(16,45,31,.18); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font:750 11px -apple-system, BlinkMacSystemFont, sans-serif; }
    .player-label small { display:block; margin-top:1px; color:#67756e; font-size:9px; }
    .calibration-pin {
      position:relative; width:40px; height:40px; transform:translate(-20px,-20px);
      border:3px solid #fff; border-radius:50%; background:#00a65a; color:#fff;
      display:flex; align-items:center; justify-content:center; overflow:visible;
      box-shadow:0 4px 16px rgba(0,73,42,.42);
      font:900 14px -apple-system, BlinkMacSystemFont, sans-serif;
      pointer-events:auto; cursor:grab; user-select:none; -webkit-user-select:none;
      touch-action:none; -webkit-tap-highlight-color:transparent;
      transition:transform .16s cubic-bezier(.2,.8,.2,1), background .16s ease,
        box-shadow .16s ease, filter .16s ease;
    }
    .calibration-pin::before {
      content:''; position:absolute; inset:-9px; border:2px solid rgba(0,166,90,.46);
      border-radius:50%; opacity:0; transform:scale(.7); pointer-events:none;
    }
    .calibration-pin:hover {
      transform:translate(-20px,-20px) scale(1.08);
      box-shadow:0 0 0 4px rgba(0,166,90,.18), 0 6px 20px rgba(0,73,42,.44);
    }
    .calibration-pin.editing {
      background:#17382b;
      box-shadow:0 0 0 5px rgba(0,166,90,.30), 0 7px 22px rgba(0,0,0,.34);
      transform:translate(-20px,-20px) scale(1.16);
      animation:calibrationSelectPop .24s cubic-bezier(.2,.9,.3,1.25);
    }
    .calibration-pin.editing::before {
      opacity:1; animation:calibrationPulse 1.15s ease-out infinite;
    }
    .calibration-pin.dragging, .calibration-pin:active {
      cursor:grabbing; background:#0b6e44; filter:brightness(1.06);
      transform:translate(-20px,-20px) scale(1.24);
      box-shadow:0 0 0 7px rgba(0,166,90,.24), 0 10px 28px rgba(0,0,0,.38);
    }
    .calibration-pin.dragging::before {
      opacity:1; animation:calibrationPulse .72s ease-out infinite;
    }
    .calibration-drag-label {
      position:absolute; left:50%; top:45px; transform:translate(-50%,-4px) scale(.94);
      padding:3px 6px; border-radius:6px; background:rgba(17,24,39,.94); color:#fff;
      box-shadow:0 4px 12px rgba(0,0,0,.24); font-size:8px; font-weight:900;
      letter-spacing:.7px; line-height:1; white-space:nowrap; opacity:0; pointer-events:none;
      transition:opacity .14s ease, transform .14s ease;
    }
    .calibration-pin.editing .calibration-drag-label,
    .calibration-pin.dragging .calibration-drag-label {
      opacity:1; transform:translate(-50%,0) scale(1);
    }
    @keyframes calibrationPulse {
      0% { opacity:.78; transform:scale(.70); }
      70%, 100% { opacity:0; transform:scale(1.32); }
    }
    @keyframes calibrationSelectPop {
      0% { transform:translate(-20px,-20px) scale(.88); }
      70% { transform:translate(-20px,-20px) scale(1.23); }
      100% { transform:translate(-20px,-20px) scale(1.16); }
    }
    .leaflet-calibration-icon {
      background:transparent !important; border:0 !important; overflow:visible !important;
      display:flex !important; align-items:center; justify-content:center;
    }
    .leaflet-calibration-icon .calibration-pin { transform:none; }
    .leaflet-calibration-icon .calibration-pin:hover { transform:scale(1.08); }
    .leaflet-calibration-icon .calibration-pin.editing { transform:scale(1.16); }
    .leaflet-calibration-icon .calibration-pin.dragging,
    .leaflet-calibration-icon .calibration-pin:active { transform:scale(1.24); }
    @keyframes calibrationSelectPopLeaflet {
      0% { transform:scale(.88); } 70% { transform:scale(1.23); } 100% { transform:scale(1.16); }
    }
    .leaflet-calibration-icon .calibration-pin.editing { animation-name:calibrationSelectPopLeaflet; }
    /* Атрибуция остаётся доступной, но не перекрывает рабочую область поля. */
    .leaflet-control-attribution {
      margin:0 2px 2px 0 !important; padding:1px 4px !important;
      border-radius:5px !important; background:rgba(255,255,255,.72) !important;
      color:#66706a !important; font-size:7px !important; line-height:1.15 !important;
      box-shadow:none !important; opacity:.66;
    }
    .leaflet-control-attribution a { color:#56615c !important; text-decoration:none !important; }
  </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  <script src="https://unpkg.com/leaflet-rotate@0.2.8/dist/leaflet-rotate.js" crossorigin=""></script>
  <script src="https://mapgl.2gis.com/api/js/v1"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const cfg = $config;
    let map = null;
    let routes = [];
    const markers = new Map();
    const markerMotion = new Map();
    let lastPayload = null;
    let firstFit = true;
    let leafletTileErrorSent = false;
    let autoAligned = false;
    let autoBaseRotation = null;
    let pendingRotationOffset = 0;
    let rotationRevision = 0;
    let activeDatasetKey = null;
    let calibrationMarkers = [];
    let calibrationShape = null;
    let calibrationCoordinates = [];
    let calibrationSignature = '';
    let fieldBoundary = null;
    let fieldBoundarySignature = '';

    function post(message) {
      try { SportotekaMap.postMessage(message); } catch (_) {}
    }
    function esc(value) {
      return String(value == null ? '' : value)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
    }
    function initials(name) {
      const parts = String(name || 'Игрок').trim().split(/\\s+/).filter(Boolean);
      return esc(parts.slice(0, 2).map((part) => part.charAt(0).toUpperCase()).join('') || '•');
    }
    function markerHtml(track, current, showLabels) {
      const avatar = String(track.avatar || '').trim();
      const photo = initials(track.name) +
        (avatar ? '<img src="' + esc(avatar) + '" alt="">' : '');
      const label = showLabels
        ? '<div class="player-label">' + esc(track.name) + '<small>' + Number(current.speed_kmh || 0).toFixed(1) + ' км/ч</small></div>'
        : '';
      return '<div class="player ' + (track.selected ? 'selected' : '') + '"><div class="player-dot" style="background:' + esc(track.color || '#16794b') + '">' + photo + '</div>' + label + '</div>';
    }
    function clearRoutes() {
      routes.forEach((route) => {
        try { cfg.satellite ? route.remove() : route.destroy(); } catch (_) {}
      });
      routes = [];
    }
    function setInteractive(enabled) {
      if (!cfg.satellite) {
        map.setOption('disableDragging', !enabled);
        return;
      }
      [
        map.dragging,
        map.touchZoom,
        map.doubleClickZoom,
        map.scrollWheelZoom,
        map.boxZoom,
        map.keyboard,
      ].forEach((handler) => {
        if (!handler) return;
        enabled ? handler.enable() : handler.disable();
      });
    }
    function leafletPlayerIcon(html) {
      return L.divIcon({
        html,
        className:'leaflet-player-icon',
        iconSize:[40, 40],
        iconAnchor:[20, 20],
      });
    }
    function setPlayerMarkerCoordinates(marker, coordinates) {
      if (cfg.satellite) {
        marker.setLatLng([coordinates[1], coordinates[0]]);
      } else {
        marker.setCoordinates(coordinates);
      }
    }
    function movePlayerMarker(id, marker, coordinates, smooth, durationMs) {
      const next = [Number(coordinates[0]), Number(coordinates[1])];
      let motion = markerMotion.get(id);
      if (!motion) {
        motion = { current:next.slice(), target:next.slice(), raf:0, token:0 };
        markerMotion.set(id, motion);
        setPlayerMarkerCoordinates(marker, next);
        return;
      }
      const unchanged = Math.abs(motion.target[0] - next[0]) < 1e-10 &&
        Math.abs(motion.target[1] - next[1]) < 1e-10;
      if (unchanged) return;
      if (motion.raf) cancelAnimationFrame(motion.raf);
      const from = motion.current ? motion.current.slice() : motion.target.slice();
      motion.target = next.slice();
      motion.token += 1;
      const token = motion.token;
      if (!smooth || typeof requestAnimationFrame !== 'function') {
        motion.current = next.slice();
        setPlayerMarkerCoordinates(marker, next);
        return;
      }
      const started = performance.now();
      const duration = Math.max(80, Math.min(1200, Number(durationMs) || 780));
      const frame = (now) => {
        if (token !== motion.token) return;
        const raw = Math.max(0, Math.min(1, (now - started) / duration));
        const t = raw * raw * (3 - 2 * raw);
        const current = [
          from[0] + (next[0] - from[0]) * t,
          from[1] + (next[1] - from[1]) * t,
        ];
        motion.current = current;
        try { setPlayerMarkerCoordinates(marker, current); } catch (_) { return; }
        if (raw < 1) {
          motion.raf = requestAnimationFrame(frame);
        } else {
          motion.raf = 0;
          motion.current = next.slice();
        }
      };
      motion.raf = requestAnimationFrame(frame);
    }
    function clearCalibrationGraphics() {
      calibrationMarkers.forEach((marker) => {
        try { cfg.satellite ? marker.remove() : marker.destroy(); } catch (_) {}
      });
      calibrationMarkers = [];
      if (calibrationShape) {
        try {
          cfg.satellite ? calibrationShape.remove() : calibrationShape.destroy();
        } catch (_) {}
        calibrationShape = null;
      }
    }
    function selectCalibrationCorner(index, event) {
      try {
        if (event && typeof event.stopPropagation === 'function') event.stopPropagation();
        if (event && typeof event.preventDefault === 'function') event.preventDefault();
      } catch (_) {}
      post('calibration-select:' + Number(index));
    }
    window.sportotekaSelectCalibration = selectCalibrationCorner;
    function calibrationPin(label, index, selected) {
      return '<div class="calibration-pin' + (selected ? ' editing' : '') +
        '" data-calibration-index="' + Number(index) + '">' +
        esc(label) + '<span class="calibration-drag-label">ТЯНИТЕ</span></div>';
    }
    function calibrationPinElement(marker) {
      try {
        const root = marker && typeof marker.getContent === 'function'
          ? marker.getContent()
          : marker && typeof marker.getElement === 'function'
            ? marker.getElement()
            : null;
        return root && root.querySelector
          ? root.querySelector('.calibration-pin')
          : null;
      } catch (_) {
        return null;
      }
    }
    function setCalibrationPinDragging(marker, dragging) {
      const pin = calibrationPinElement(marker);
      if (!pin || !pin.classList) return;
      pin.classList.toggle('dragging', !!dragging);
    }
    function updateSatelliteCalibrationShape() {
      if (!cfg.satellite || !calibrationShape || calibrationCoordinates.length < 2) return;
      const latLngs = calibrationCoordinates.map((value) => [value[1], value[0]]);
      try {
        calibrationShape.setLatLngs(latLngs);
      } catch (_) {}
    }
    function bindMapGlCalibrationDrag(marker, index) {
      const pin = calibrationPinElement(marker);
      if (!pin || !pin.addEventListener) return;
      pin.addEventListener('pointerdown', (downEvent) => {
        if (!lastPayload || !lastPayload.calibration_enabled) return;
        try { downEvent.preventDefault(); downEvent.stopPropagation(); } catch (_) {}
        const pointerId = downEvent.pointerId;
        const startX = Number(downEvent.clientX || 0);
        const startY = Number(downEvent.clientY || 0);
        let moved = false;
        setCalibrationPinDragging(marker, true);
        setInteractive(false);
        try { if (pin.setPointerCapture) pin.setPointerCapture(pointerId); } catch (_) {}

        const move = (moveEvent) => {
          if (moveEvent.pointerId !== pointerId) return;
          const dx = Number(moveEvent.clientX || 0) - startX;
          const dy = Number(moveEvent.clientY || 0) - startY;
          if (!moved && Math.hypot(dx, dy) < 4) return;
          moved = true;
          try { moveEvent.preventDefault(); moveEvent.stopPropagation(); } catch (_) {}
          const rect = document.getElementById('map').getBoundingClientRect();
          const coordinate = coordinateFromScreen([
            Number(moveEvent.clientX || 0) - rect.left,
            Number(moveEvent.clientY || 0) - rect.top,
          ]);
          if (!validCoordinate(coordinate)) return;
          calibrationCoordinates[index] = [Number(coordinate[0]), Number(coordinate[1])];
          try { marker.setCoordinates(calibrationCoordinates[index]); } catch (_) {}
        };

        const finish = (upEvent) => {
          if (upEvent.pointerId !== pointerId) return;
          document.removeEventListener('pointermove', move, true);
          document.removeEventListener('pointerup', finish, true);
          document.removeEventListener('pointercancel', finish, true);
          try { if (pin.releasePointerCapture) pin.releasePointerCapture(pointerId); } catch (_) {}
          setCalibrationPinDragging(marker, false);
          setInteractive(true);
          try { upEvent.preventDefault(); upEvent.stopPropagation(); } catch (_) {}
          if (moved) {
            renderCalibration(calibrationCoordinates);
            postCalibration();
            post('calibration-select:-1');
          } else {
            selectCalibrationCorner(index, upEvent);
          }
        };

        document.addEventListener('pointermove', move, true);
        document.addEventListener('pointerup', finish, true);
        document.addEventListener('pointercancel', finish, true);
      }, { passive:false });
    }
    function validCoordinate(value) {
      return Array.isArray(value) && value.length >= 2 &&
        Number.isFinite(Number(value[0])) && Number.isFinite(Number(value[1])) &&
        Math.abs(Number(value[0])) <= 180 && Math.abs(Number(value[1])) <= 90;
    }
    function renderCalibration(coordinates) {
      const nextCoordinates = (coordinates || [])
        .filter(validCoordinate)
        .slice(0, 4)
        .map((value) => [Number(value[0]), Number(value[1])]);
      const editingRaw = lastPayload && lastPayload.calibration_editing_index;
      const editingIndex = editingRaw === null || editingRaw === undefined
        ? -1
        : Number(editingRaw);
      const geometrySignature = JSON.stringify(nextCoordinates);
      const previousGeometrySignature = calibrationSignature.split('|edit:')[0];
      const nextSignature = geometrySignature + '|edit:' +
        (Number.isInteger(editingIndex) ? editingIndex : -1);
      calibrationCoordinates = nextCoordinates;
      if (nextSignature === calibrationSignature) return;
      calibrationSignature = nextSignature;
      if (geometrySignature !== previousGeometrySignature) {
        autoAligned = false;
        autoBaseRotation = null;
        rotationRevision += 1;
      }
      clearCalibrationGraphics();
      const labels = ['A', 'B', 'C', 'D'];
      calibrationCoordinates.forEach((coordinates, index) => {
        const html = calibrationPin(labels[index], index, editingIndex === index);
        if (cfg.satellite) {
          const marker = L.marker(
            [coordinates[1], coordinates[0]],
            {
              icon:L.divIcon({
                html,
                className:'leaflet-calibration-icon',
                iconSize:[44, 44],
                iconAnchor:[22, 22],
              }),
              interactive:true,
              keyboard:false,
              draggable:true,
              autoPan:true,
              zIndexOffset:4000 + index,
            },
          ).addTo(map);
          let calibrationMarkerMoved = false;
          marker.on('dragstart', () => {
            calibrationMarkerMoved = false;
            setCalibrationPinDragging(marker, true);
          });
          marker.on('drag', (markerEvent) => {
            calibrationMarkerMoved = true;
            const latLng = markerEvent && markerEvent.target
              ? markerEvent.target.getLatLng()
              : marker.getLatLng();
            if (!latLng) return;
            calibrationCoordinates[index] = [Number(latLng.lng), Number(latLng.lat)];
            updateSatelliteCalibrationShape();
          });
          marker.on('dragend', () => {
            setCalibrationPinDragging(marker, false);
            if (!calibrationMarkerMoved) return;
            renderCalibration(calibrationCoordinates);
            postCalibration();
            post('calibration-select:-1');
          });
          marker.on('click', (markerEvent) => {
            try { L.DomEvent.stopPropagation(markerEvent); } catch (_) {}
            if (calibrationMarkerMoved) {
              calibrationMarkerMoved = false;
              return;
            }
            selectCalibrationCorner(index, markerEvent.originalEvent);
          });
          calibrationMarkers.push(marker);
        } else {
          const marker = new mapgl.HtmlMarker(map, {
            coordinates,
            html,
            anchor:[0, 0],
            zIndex:40 + index,
            interactive:true,
            preventMapInteractions:true,
          });
          bindMapGlCalibrationDrag(marker, index);
          calibrationMarkers.push(marker);
        }
      });
      if (calibrationCoordinates.length < 2) return;
      if (cfg.satellite) {
        const latLngs = calibrationCoordinates.map((value) => [value[1], value[0]]);
        calibrationShape = calibrationCoordinates.length >= 3
          ? L.polygon(latLngs, {
              color:'#00a65a', weight:3, opacity:.95,
              fillColor:'#00a65a', fillOpacity:.16, interactive:false,
            }).addTo(map)
          : L.polyline(latLngs, {
              color:'#00a65a', weight:3, opacity:.95, interactive:false,
            }).addTo(map);
        return;
      }
      if (calibrationCoordinates.length >= 3) {
        const ring = calibrationCoordinates.concat([calibrationCoordinates[0]]);
        calibrationShape = new mapgl.Polygon(map, {
          coordinates:[ring],
          color:'#00a65a2b',
          strokeColor:'#00a65a',
          strokeWidth:3,
        });
      } else {
        calibrationShape = new mapgl.Polyline(map, {
          coordinates:calibrationCoordinates,
          color:'#00a65a',
          width:3,
        });
      }
    }
    function renderFieldBoundary(coordinates) {
      const nextCoordinates = (coordinates || [])
        .filter(validCoordinate)
        .slice(0, 4)
        .map((value) => [Number(value[0]), Number(value[1])]);
      const nextSignature = JSON.stringify(nextCoordinates);
      if (nextSignature === fieldBoundarySignature) return;
      fieldBoundarySignature = nextSignature;
      if (fieldBoundary) {
        try { cfg.satellite ? fieldBoundary.remove() : fieldBoundary.destroy(); }
        catch (_) {}
        fieldBoundary = null;
      }
      if (nextCoordinates.length < 4) return;
      if (cfg.satellite) {
        fieldBoundary = L.polygon(
          nextCoordinates.map((value) => [value[1], value[0]]),
          {
            color:'#00a65a', weight:2, opacity:.82,
            fillColor:'#00a65a', fillOpacity:.055,
            dashArray:'7 6', interactive:false,
          },
        ).addTo(map);
        return;
      }
      const ring = nextCoordinates.concat([nextCoordinates[0]]);
      fieldBoundary = new mapgl.Polygon(map, {
        coordinates:[ring],
        color:'#00a65a0e',
        strokeColor:'#00a65a',
        strokeWidth:2,
      });
    }
    function eventCoordinate(event) {
      if (!event) return null;
      if (validCoordinate(event.lngLat)) return [Number(event.lngLat[0]), Number(event.lngLat[1])];
      if (event.lngLat && Number.isFinite(Number(event.lngLat.lng)) &&
          Number.isFinite(Number(event.lngLat.lat))) {
        return [Number(event.lngLat.lng), Number(event.lngLat.lat)];
      }
      if (validCoordinate(event.coordinates)) {
        return [Number(event.coordinates[0]), Number(event.coordinates[1])];
      }
      if (event.latlng && Number.isFinite(Number(event.latlng.lng)) &&
          Number.isFinite(Number(event.latlng.lat))) {
        return [Number(event.latlng.lng), Number(event.latlng.lat)];
      }
      if (Array.isArray(event.point) && event.point.length >= 2 && !cfg.satellite) {
        return map.unproject([Number(event.point[0]), Number(event.point[1])]);
      }
      return null;
    }
    function coordinateFromScreen(point) {
      if (cfg.satellite) {
        const latLng = map.containerPointToLatLng(L.point(point[0], point[1]));
        return [latLng.lng, latLng.lat];
      }
      return map.unproject(point);
    }
    function rectangleFromDiagonal(a, b) {
      const pa = projectedPoint(a);
      const pb = projectedPoint(b);
      const left = Math.min(pa[0], pb[0]);
      const right = Math.max(pa[0], pb[0]);
      const top = Math.min(pa[1], pb[1]);
      const bottom = Math.max(pa[1], pb[1]);
      return [
        coordinateFromScreen([left, top]),
        coordinateFromScreen([right, top]),
        coordinateFromScreen([right, bottom]),
        coordinateFromScreen([left, bottom]),
      ];
    }
    function postCalibration() {
      post('calibration:' + JSON.stringify(calibrationCoordinates));
    }
    function handleCalibrationClick(event) {
      if (!lastPayload || !lastPayload.calibration_enabled) return;
      const coordinate = eventCoordinate(event);
      if (!validCoordinate(coordinate)) return;
      const editingRaw = lastPayload.calibration_editing_index;
      const editingIndex = editingRaw === null || editingRaw === undefined
        ? -1
        : Number(editingRaw);
      if (Number.isInteger(editingIndex) && editingIndex >= 0 &&
          editingIndex < calibrationCoordinates.length) {
        calibrationCoordinates = calibrationCoordinates.map(
          (value, index) => index === editingIndex ? coordinate : value
        );
        renderCalibration(calibrationCoordinates);
        postCalibration();
        post('calibration-select:-1');
        return;
      }
      if (lastPayload.calibration_mode === 'rectangle') {
        if (calibrationCoordinates.length === 0) {
          calibrationCoordinates = [coordinate];
        } else if (calibrationCoordinates.length === 1) {
          calibrationCoordinates = rectangleFromDiagonal(
            calibrationCoordinates[0],
            coordinate
          );
        } else {
          return;
        }
      } else {
        if (calibrationCoordinates.length >= 4) return;
        calibrationCoordinates = calibrationCoordinates.concat([coordinate]);
      }
      renderCalibration(calibrationCoordinates);
      postCalibration();
    }
    function normalizeAxisAngle(value) {
      let result = Number(value || 0);
      while (result > 90) result -= 180;
      while (result <= -90) result += 180;
      return result;
    }
    function setRawRotation(value) {
      const rotation = Number.isFinite(Number(value)) ? Number(value) : 0;
      if (cfg.satellite) {
        if (typeof map.setBearing === 'function') map.setBearing(rotation);
        return;
      }
      map.setRotation(rotation, { duration:0 });
    }
    function projectedPoint(coordinates) {
      if (cfg.satellite) {
        const point = map.latLngToContainerPoint([coordinates[1], coordinates[0]]);
        return [point.x, point.y];
      }
      const point = map.project(coordinates);
      return [point[0], point[1]];
    }
    function projectedAxisAngle(axis) {
      if (!axis || axis.length < 2) return 0;
      const a = projectedPoint(axis[0]);
      const b = projectedPoint(axis[1]);
      return normalizeAxisAngle(
        Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI
      );
    }
    function distanceMeters(a, b) {
      const meanLat = (a[1] + b[1]) * .5 * Math.PI / 180;
      const dx = (a[0] - b[0]) * 111320 * Math.cos(meanLat);
      const dy = (a[1] - b[1]) * 110540;
      return Math.sqrt(dx * dx + dy * dy);
    }
    function meanCoordinate(coordinates) {
      if (!coordinates.length) return null;
      return coordinates.reduce(
        (sum, value) => [sum[0] + value[0], sum[1] + value[1]],
        [0, 0]
      ).map((value) => value / coordinates.length);
    }
    function pointInPolygon(point, polygon) {
      let inside = false;
      for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        const xi = polygon[i][0], yi = polygon[i][1];
        const xj = polygon[j][0], yj = polygon[j][1];
        const intersects = ((yi > point[1]) !== (yj > point[1])) &&
          (point[0] < (xj - xi) * (point[1] - yi) /
            ((yj - yi) || 1e-12) + xi);
        if (intersects) inside = !inside;
      }
      return inside;
    }
    function distanceToSegmentMeters(point, a, b) {
      const scaleX = 111320 * Math.cos(point[1] * Math.PI / 180);
      const ax = (a[0] - point[0]) * scaleX;
      const ay = (a[1] - point[1]) * 110540;
      const bx = (b[0] - point[0]) * scaleX;
      const by = (b[1] - point[1]) * 110540;
      const dx = bx - ax, dy = by - ay;
      const den = dx * dx + dy * dy;
      const t = den <= 1e-9
        ? 0
        : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / den));
      const x = ax + dx * t, y = ay + dy * t;
      return Math.sqrt(x * x + y * y);
    }
    function pointNearPolygon(point, polygon, paddingMeters) {
      if (pointInPolygon(point, polygon)) return true;
      for (let index = 0; index < polygon.length; index++) {
        const next = (index + 1) % polygon.length;
        if (distanceToSegmentMeters(point, polygon[index], polygon[next]) <= paddingMeters) {
          return true;
        }
      }
      return false;
    }
    function calibratedLongAxis(corners, gpsCoordinates) {
      if (corners.length < 4 || !gpsCoordinates.length) return null;
      const fieldCenter = meanCoordinate(corners);
      const gpsCenter = meanCoordinate(gpsCoordinates);
      if (!fieldCenter || !gpsCenter || distanceMeters(fieldCenter, gpsCenter) > 120) {
        return null;
      }
      const nearCount = gpsCoordinates.filter(
        (point) => pointNearPolygon(point, corners, 20)
      ).length;
      if (nearCount < Math.max(1, Math.ceil(gpsCoordinates.length * .25))) {
        return null;
      }
      const edges = [
        [corners[0], corners[1]],
        [corners[1], corners[2]],
        [corners[2], corners[3]],
        [corners[3], corners[0]],
      ];
      edges.sort((a, b) => distanceMeters(b[0], b[1]) - distanceMeters(a[0], a[1]));
      return edges[0];
    }
    function dominantAxis(payload, coordinates, currentCoordinates) {
      const draftCorners = (payload.calibration_corners || []).filter((value) =>
        Array.isArray(value) && Number.isFinite(value[0]) && Number.isFinite(value[1])
      );
      if (payload.calibration_enabled && draftCorners.length >= 4) {
        const draftEdges = [
          [draftCorners[0], draftCorners[1]],
          [draftCorners[1], draftCorners[2]],
          [draftCorners[2], draftCorners[3]],
          [draftCorners[3], draftCorners[0]],
        ];
        draftEdges.sort(
          (a, b) => distanceMeters(b[0], b[1]) - distanceMeters(a[0], a[1])
        );
        return draftEdges[0];
      }
      const corners = (payload.field_corners || []).filter((value) =>
        Array.isArray(value) && Number.isFinite(value[0]) && Number.isFinite(value[1])
      );
      const calibratedAxis = calibratedLongAxis(
        corners,
        currentCoordinates.length ? currentCoordinates : coordinates
      );
      // Корректная близкая к трекерам калибровка задаёт стабильную альбомную
      // ориентацию. Старая калибровка соседнего поля отсеивается проверкой
      // попадания GPS в контур (с допуском 20 м).
      if (calibratedAxis) return calibratedAxis;
      if (coordinates.length < 8) return calibratedAxis;

      const step = Math.max(1, Math.floor(coordinates.length / 1200));
      const sample = [];
      for (let index = 0; index < coordinates.length; index += step) {
        sample.push(coordinates[index]);
      }
      const mean = sample.reduce(
        (sum, value) => [sum[0] + value[0], sum[1] + value[1]],
        [0, 0]
      ).map((value) => value / sample.length);
      const lonScale = Math.max(.2, Math.cos(mean[1] * Math.PI / 180));
      let xx = 0, xy = 0, yy = 0;
      sample.forEach((value) => {
        const x = (value[0] - mean[0]) * lonScale;
        const y = value[1] - mean[1];
        xx += x * x; xy += x * y; yy += y * y;
      });
      if (xx + yy < 1e-14) return calibratedAxis;
      const angle = .5 * Math.atan2(2 * xy, xx - yy);
      const vx = Math.cos(angle), vy = Math.sin(angle);
      let minProjection = Infinity, maxProjection = -Infinity;
      sample.forEach((value) => {
        const x = (value[0] - mean[0]) * lonScale;
        const y = value[1] - mean[1];
        const projection = x * vx + y * vy;
        minProjection = Math.min(minProjection, projection);
        maxProjection = Math.max(maxProjection, projection);
      });
      if (!Number.isFinite(minProjection) || maxProjection - minProjection < 1e-7) {
        return calibratedAxis;
      }
      return [
        [mean[0] + vx * minProjection / lonScale, mean[1] + vy * minProjection],
        [mean[0] + vx * maxProjection / lonScale, mean[1] + vy * maxProjection],
      ];
    }
    function applyRotation(payload, coordinates, currentCoordinates) {
      const manual = payload.rotation_deg;
      pendingRotationOffset = manual !== null && manual !== undefined &&
          Number.isFinite(Number(manual))
        ? Number(manual)
        : 0;
      if (autoBaseRotation !== null) {
        setRawRotation(autoBaseRotation + pendingRotationOffset);
        return;
      }
      if (autoAligned) return;
      const axis = dominantAxis(payload, coordinates, currentCoordinates);
      if (!axis) {
        setRawRotation(pendingRotationOffset);
        return;
      }

      autoAligned = true;
      const revision = ++rotationRevision;
      setRawRotation(0);
      // Измеряем реальный угол уже после проекции движка. Это одинаково
      // работает для MapGL и Leaflet и не зависит от порядка углов поля.
      setTimeout(() => {
        if (revision !== rotationRevision) return;
        const angle = projectedAxisAngle(axis);
        if (Math.abs(angle) < .5) {
          autoBaseRotation = 0;
          setRawRotation(pendingRotationOffset);
          return;
        }
        let candidate = -angle;
        setRawRotation(candidate);
        // У движков противоположные соглашения о знаке поворота. Проверяем
        // результат на экране и при необходимости меняем знак один раз.
        setTimeout(() => {
          if (revision !== rotationRevision) return;
          const remaining = projectedAxisAngle(axis);
          if (Math.abs(remaining) > Math.max(2, Math.abs(angle) * .75)) {
            candidate = angle;
          }
          autoBaseRotation = candidate;
          setRawRotation(autoBaseRotation + pendingRotationOffset);
        }, 90);
      }, 90);
    }
    function fitAll(coordinates) {
      if (!coordinates.length) return;
      if (cfg.satellite) {
        const latLngs = coordinates.map((value) => [value[1], value[0]]);
        if (latLngs.length === 1) {
          map.setView(latLngs[0], 18, { animate:false });
        } else {
          map.fitBounds(latLngs, {
            padding:[64, 64],
            animate:false,
            maxZoom:19,
          });
        }
        return;
      }
      if (coordinates.length === 1) {
        map.setCenter(coordinates[0], { duration: 0 });
        map.setZoom(18, { duration: 0 });
        return;
      }
      let minLon = coordinates[0][0], maxLon = minLon;
      let minLat = coordinates[0][1], maxLat = minLat;
      coordinates.forEach((value) => {
        minLon = Math.min(minLon, value[0]); maxLon = Math.max(maxLon, value[0]);
        minLat = Math.min(minLat, value[1]); maxLat = Math.max(maxLat, value[1]);
      });
      map.fitBounds(
        { southWest:[minLon, minLat], northEast:[maxLon, maxLat] },
        { padding:{ top:64, left:64, bottom:64, right:64 }, duration:0 }
      );
    }
    function render(payload) {
      if (!map || !payload) return;
      lastPayload = payload;
      const datasetKey = String(payload.dataset_key || '');
      if (activeDatasetKey === null || (!payload.live && activeDatasetKey !== datasetKey)) {
        activeDatasetKey = datasetKey;
        firstFit = true;
        autoAligned = false;
        autoBaseRotation = null;
        rotationRevision += 1;
      }
      try {
        map.getContainer().style.cursor = payload.calibration_enabled
          ? 'crosshair'
          : '';
      } catch (_) {}
      setInteractive(payload.interactive);
      clearRoutes();
      const alive = new Set();
      const allCoordinates = [];
      const followPoints = [];
      const orientationCoordinates = (payload.orientation_points || []).filter(
        (value) => Array.isArray(value) &&
          Number.isFinite(value[0]) && Number.isFinite(value[1])
      );
      (payload.tracks || []).forEach((track) => {
        const points = (track.points || []).filter((point) => Number.isFinite(point.lon) && Number.isFinite(point.lat));
        const segments = [];
        let segment = [];
        points.forEach((point) => {
          const coord = [point.lon, point.lat];
          allCoordinates.push(coord);
          if (point.break_before && segment.length) { segments.push(segment); segment = []; }
          segment.push(coord);
        });
        if (segment.length) segments.push(segment);
        if (payload.show_trace) {
          segments.filter((value) => value.length >= 2).forEach((coordinates) => {
            const baseColor = track.color || '#16794b';
            if (cfg.satellite) {
              routes.push(L.polyline(
                coordinates.map((value) => [value[1], value[0]]),
                {
                  color:baseColor,
                  weight:track.selected ? 4 : 2,
                  opacity:track.selected ? 1 : 0.55,
                  interactive:false,
                },
              ).addTo(map));
            } else {
              const routeColor = track.selected ? baseColor : baseColor + '88';
              routes.push(new mapgl.Polyline(map, {
                coordinates,
                color:routeColor,
                width:track.selected ? 4 : 2,
              }));
            }
          });
        }
        const current = track.current;
        if (!current) return;
        const coordinates = [current.lon, current.lat];
        followPoints.push(coordinates);
        if (!payload.show_players) return;
        alive.add(track.id);
        const html = markerHtml(track, current, payload.show_labels);
        let marker = markers.get(track.id);
        if (cfg.satellite) {
          const latLng = [coordinates[1], coordinates[0]];
          const icon = leafletPlayerIcon(html);
          if (!marker) {
            marker = L.marker(latLng, {
              icon,
              interactive:false,
              keyboard:false,
              zIndexOffset:track.selected ? 2000 : 1000,
            }).addTo(map);
            markers.set(track.id, marker);
            markerMotion.set(track.id, { current:coordinates.slice(), target:coordinates.slice(), raf:0, token:0 });
          } else {
            movePlayerMarker(
              track.id,
              marker,
              coordinates,
              Boolean(payload.live || payload.smooth_player_motion),
              payload.player_motion_duration_ms,
            );
            marker.setIcon(icon);
            marker.setZIndexOffset(track.selected ? 2000 : 1000);
          }
        } else if (!marker) {
          marker = new mapgl.HtmlMarker(map, {
            coordinates,
            html,
            anchor:[0, 0],
            zIndex:track.selected ? 20 : 10,
          });
          markers.set(track.id, marker);
          markerMotion.set(track.id, { current:coordinates.slice(), target:coordinates.slice(), raf:0, token:0 });
        } else {
          movePlayerMarker(
              track.id,
              marker,
              coordinates,
              Boolean(payload.live || payload.smooth_player_motion),
              payload.player_motion_duration_ms,
            );
          marker.setContent(html);
          marker.setZIndex(track.selected ? 20 : 10);
        }
      });
      markers.forEach((marker, id) => {
        if (!alive.has(id)) {
          try { cfg.satellite ? marker.remove() : marker.destroy(); } catch (_) {}
          const motion = markerMotion.get(id);
          if (motion && motion.raf) cancelAnimationFrame(motion.raf);
          markerMotion.delete(id);
          markers.delete(id);
        }
      });
      renderCalibration(
        payload.calibration_enabled ? (payload.calibration_corners || []) : []
      );
      renderFieldBoundary(
        payload.calibration_enabled ? [] : (payload.field_corners || [])
      );
      // Геокарта всегда открывается по фактическим текущим GPS игроков.
      // Калибровка может относиться к старому полю и не должна уводить камеру.
      const initialCenter = validCoordinate(payload.initial_center)
        ? [Number(payload.initial_center[0]), Number(payload.initial_center[1])]
        : null;
      const fitCoordinates = calibrationCoordinates.length
        ? calibrationCoordinates
        : (followPoints.length
            ? followPoints
            : (allCoordinates.length
                ? allCoordinates
                : (initialCenter ? [initialCenter] : [])));
      if (firstFit && fitCoordinates.length) {
        fitAll(fitCoordinates);
        firstFit = false;
      } else if (payload.live && payload.follow && followPoints.length) {
        const center = followPoints.reduce(
          (sum, point) => [sum[0] + point[0], sum[1] + point[1]],
          [0, 0]
        ).map((value) => value / followPoints.length);
        if (cfg.satellite) {
          map.panTo([center[1], center[0]], { animate:true, duration:0.68 });
        } else {
          map.setCenter(center, { duration:680 });
        }
      }
      applyRotation(
        payload,
        orientationCoordinates.length ? orientationCoordinates : allCoordinates,
        followPoints
      );
      if (cfg.satellite) {
        map.invalidateSize(false);
      } else {
        map.setPitch(Number(payload.pitch || 0), { duration:160 });
      }
    }
    window.sportotekaUpdate = function(raw) {
      try { render(typeof raw === 'string' ? JSON.parse(raw) : raw); }
      catch (_) { post('error:Не удалось обновить GPS на карте'); }
    };
    try {
      if (cfg.satellite) {
        if (!window.L || !cfg.satellite_url) {
          throw new Error('Leaflet satellite source is unavailable');
        }
        map = L.map('map', {
          center:[52.425, 30.985],
          zoom:16,
          zoomControl:false,
          attributionControl:false,
          preferCanvas:true,
          rotate:true,
          bearing:0,
          touchRotate:true,
          rotateControl:false,
        });
        L.control.zoom({ position:'topright' }).addTo(map);
        L.control.attribution({ position:'bottomleft', prefix:false }).addTo(map);
        const satelliteTiles = L.tileLayer(cfg.satellite_url, {
          attribution:cfg.satellite_attribution || 'MapTiler',
          minZoom:0,
          maxZoom:22,
          maxNativeZoom:20,
          tileSize:256,
          detectRetina:false,
          crossOrigin:true,
          keepBuffer:3,
          updateWhenIdle:false,
        });
        let tileErrors = 0;
        satelliteTiles.on('tileload', () => { tileErrors = 0; });
        satelliteTiles.on('tileerror', () => {
          tileErrors += 1;
          if (tileErrors >= 4 && !leafletTileErrorSent) {
            leafletTileErrorSent = true;
            post('error:Спутниковые снимки не загрузились — проверьте ключ MapTiler');
          }
        });
        satelliteTiles.addTo(map);
        setTimeout(() => map.invalidateSize(false), 0);
      } else {
        map = new mapgl.Map('map', {
          key:cfg.key,
          center:[30.985, 52.425],
          zoom:16,
          pitch:0,
          rotation:0,
          language:'ru',
          copyright:'bottomLeft',
          controlsLayoutPadding:{ top:42, right:4, bottom:4, left:4 },
          zoomControl:true,
          trafficControl:false,
          disableRotationByUserInteraction:false,
        });
      }
      map.on('click', handleCalibrationClick);
      post('ready');
    } catch (error) {
      post(cfg.satellite
        ? 'error:Не удалось открыть спутниковую карту'
        : 'error:Проверьте ключ 2ГИС и доступ к сети');
    }
  </script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (!Tracker2GisMapLayer.hasMapKey) {
      return _MapSetupPlaceholder(
        icon: widget.layer.icon,
        title: 'Ключ карты пока не подключён',
        detail:
            'Текущая карта поля продолжает работать. Добавьте DGIS_MAPGL_KEY при сборке — экран менять не потребуется.',
      );
    }

    final hasPoints = widget.tracks.any(
      (track) => track.points.any((point) => point.isValid),
    );
    if (!hasPoints && !widget.calibrationEnabled) {
      return const _MapSetupPlaceholder(
        icon: Icons.gps_off_rounded,
        title: 'Нет координат для карты',
        detail: 'Как только придут реальные GPS-точки, маршрут появится здесь.',
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        Positioned(
          left: 0,
          bottom: 0,
          child: IgnorePointer(
            child: _MapBrandBottomBadge(
              title: widget.layer == TrackerGeoBaseLayer.satellite
                  ? 'Спутник'
                  : 'Карта',
            ),
          ),
        ),
        if (_pageLoading)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x99F1F4F2),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF16794B),
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Positioned.fill(
            child: _MapSetupPlaceholder(
              icon: Icons.wifi_off_rounded,
              title: _error!,
              detail: 'Поле доступно через переключатель подложки.',
              onRetry: () {
                setState(() {
                  _error = null;
                  _mapReady = false;
                });
                unawaited(_loadMap());
              },
            ),
          ),
        if (widget.layer == TrackerGeoBaseLayer.satellite &&
            !Tracker2GisMapLayer.hasSatelliteSource)
          const Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: _MapStatusBadge(
                icon: Icons.satellite_alt_rounded,
                text:
                    'Спутниковый источник не задан — показана карта',
              ),
            ),
          ),
      ],
    );
  }
}


class _MapBrandBottomBadge extends StatelessWidget {
  const _MapBrandBottomBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: const _MapBrandBottomClipper(),
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(.16),
      child: SizedBox(
        width: 138,
        height: 54,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 18, 34, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.map_rounded,
                size: 14,
                color: Color(0xFF16794B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF26332D),
                    fontSize: 10.6,
                    fontWeight: FontWeight.w900,
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

class _MapBrandBottomClipper extends CustomClipper<Path> {
  const _MapBrandBottomClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * .72, 0);
    path.lineTo(size.width, size.height * .34);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MapSetupPlaceholder extends StatelessWidget {
  const _MapSetupPlaceholder({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2F1E8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF16794B), size: 25),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF23342C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7871),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E3DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: const Color(0xFF16794B)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF35463D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
