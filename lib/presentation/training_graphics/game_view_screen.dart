// lib/presentation/training_graphics/game_view_screen.dart
// Sportoteka Training Graphics — inline GLB field mode on Thermion/Filament.
// The 3D renderer is an additional field/view mode inside the editor.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as thermion;

import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';

class TrainingGraphicsGlbFieldController {
  _TrainingGraphicsGlbFieldViewState? _state;

  void _attach(_TrainingGraphicsGlbFieldViewState state) => _state = state;
  void _detach(_TrainingGraphicsGlbFieldViewState state) {
    if (identical(_state, state)) _state = null;
  }

  void handlePointerDown(PointerDownEvent event) =>
      _state?._onExternalPointerDown(event);
  void handlePointerMove(PointerMoveEvent event) =>
      _state?._onExternalPointerMove(event);
  void handlePointerUp(PointerUpEvent event) =>
      _state?._onExternalPointerUp(event);
  void handlePointerCancel(PointerCancelEvent event) =>
      _state?._onExternalPointerCancel(event);
  void handlePointerSignal(PointerSignalEvent event) =>
      _state?._onExternalPointerSignal(event);

  void orbitBy(Offset delta) => _state?._orbitBy(delta);
  void zoomIn() => _state?._zoomBy(.90);
  void zoomOut() => _state?._zoomBy(1.10);
  void reset() => _state?._resetCamera();
}

/// Inline 3D field that is embedded into the main Training Graphics workspace.
/// It deliberately has no Scaffold or its own top navigation: the surrounding
/// editor remains visible and owns all panels/actions.
class TrainingGraphicsGlbFieldView extends StatefulWidget {
  const TrainingGraphicsGlbFieldView({
    super.key,
    required this.state,
    this.onTogglePlayback,
    this.playbackRunning = false,
    this.enableCameraInput = true,
    this.showStatusBadge = true,
    this.controller,
    this.onCameraChanged,
    this.onProjectionChanged,
  });

  final TgState state;
  final VoidCallback? onTogglePlayback;
  final bool playbackRunning;
  final bool enableCameraInput;
  final bool showStatusBadge;
  final TrainingGraphicsGlbFieldController? controller;
  final void Function(double yaw, double pitch, double radius)? onCameraChanged;

  /// Exact scene-to-viewport homography for the football pitch plane.
  /// The 16 values use Matrix4 storage order and can be passed directly to
  /// vector_math Matrix4.fromList in the editor overlay.
  final ValueChanged<List<double>>? onProjectionChanged;

  @override
  State<TrainingGraphicsGlbFieldView> createState() =>
      _TrainingGraphicsGlbFieldViewState();
}

class _TrainingGraphicsGlbFieldViewState
    extends State<TrainingGraphicsGlbFieldView> {
  bool _viewerReady = false;
  String? _error;

  // We deliberately handle orbit input ourselves instead of using Thermion's
  // built-in desktop manipulator. On macOS the bundled manipulator can remain
  // in a pressed/drag state after the mouse button is released. Keeping the
  // pointer session in Flutter makes button-up/cancel deterministic.
  dynamic _camera;
  bool _orbitDragging = false;
  int? _orbitPointer;
  Offset? _lastPointerPosition;
  double _orbitYaw = 0.0;
  double _orbitPitch = 1.36;
  double _orbitRadius = 100.0;
  double _verticalFovDegrees = 66.0;
  int _orbitButtons = 0;
  Size _viewportSize = Size.zero;

  static const double _logicalFieldLength = 1050.0;
  static const double _logicalFieldWidth = 680.0;
  // Keep the GLB in its native football dimensions. stadium_field_only.glb
  // contains pitch markings whose measured bounds are ~105.195 x 68.063.
  // Mapping the editor's 1050 x 680 logical pitch directly to these source
  // coordinates avoids the scaling mismatch seen with Thermion 0.3.4.
  static const double _worldFieldLength = 105.1949;
  static const double _worldFieldWidth = 68.0633;
  static const double _worldFieldCenterX = -0.00555;
  static const double _worldFieldPlaneY = 0.0095;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant TrainingGraphicsGlbFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  Future<void> _applyOrbitCamera() async {
    final camera = _camera;
    if (camera == null) return;

    final horizontal = _orbitRadius * math.cos(_orbitPitch);
    final position = thermion.Vector3(
      horizontal * math.sin(_orbitYaw),
      _orbitRadius * math.sin(_orbitPitch),
      horizontal * math.cos(_orbitYaw),
    );
    await camera.lookAt(position, focus: thermion.Vector3(0, 0.0, 0));
    await _applyCameraProjection();
    _emitProjectionMatrix();
    widget.onCameraChanged?.call(_orbitYaw, _orbitPitch, _orbitRadius);
  }

  Future<void> _applyCameraProjection() async {
    final camera = _camera;
    final size = _viewportSize;
    if (camera == null || size.width <= 1 || size.height <= 1) return;
    final aspect = size.width / size.height;
    try {
      await camera.setProjectionFromVerticalFieldOfView(
        _verticalFovDegrees,
        0.05,
        1200.0,
        aspect,
      );
    } catch (_) {
      // Keep rendering even on an older camera implementation. The current
      // Thermion branch supports this method, but the guard keeps the editor
      // usable if the package is swapped later.
    }
  }

  void _emitProjectionMatrix() {
    final size = _viewportSize;
    if (size.width <= 1 || size.height <= 1) return;

    final cp = math.cos(_orbitPitch);
    final sp = math.sin(_orbitPitch);
    final sy = math.sin(_orbitYaw);
    final cy = math.cos(_orbitYaw);

    // Camera position generated by _applyOrbitCamera.
    final px = _orbitRadius * cp * sy;
    final py = _orbitRadius * sp;
    final pz = _orbitRadius * cp * cy;

    // Camera forward = normalize(origin - position).
    final fx = -cp * sy;
    final fy = -sp;
    final fz = -cp * cy;

    // right = normalize(forward x worldUp).
    final rightLen = math.sqrt(fx * fx + fz * fz).clamp(1e-9, double.infinity).toDouble();
    final rx = -fz / rightLen;
    final ry = 0.0;
    final rz = fx / rightLen;

    // camera up = right x forward.
    final ux = ry * fz - rz * fy;
    final uy = rz * fx - rx * fz;
    final uz = rx * fy - ry * fx;

    // Logical scene -> real pitch plane. In the editor X is field length and
    // Y is field width; in the GLB, Z is length and X is width.
    final bzX = _worldFieldLength / _logicalFieldLength;
    final bxY = _worldFieldWidth / _logicalFieldWidth;
    final cwx = _worldFieldCenterX - _worldFieldWidth * .5;
    final cwy = _worldFieldPlaneY;
    final cwz = -_worldFieldLength * .5;

    double coeffX(double qx, double qy, double qz) => qz * bzX;
    double coeffY(double qx, double qy, double qz) => qx * bxY;
    double coeff0(double qx, double qy, double qz) =>
        (cwx - px) * qx + (cwy - py) * qy + (cwz - pz) * qz;

    final cxX = coeffX(rx, ry, rz);
    final cxY = coeffY(rx, ry, rz);
    final cx0 = coeff0(rx, ry, rz);
    final cyX = coeffX(ux, uy, uz);
    final cyY = coeffY(ux, uy, uz);
    final cy0 = coeff0(ux, uy, uz);
    final czX = coeffX(fx, fy, fz);
    final czY = coeffY(fx, fy, fz);
    final cz0 = coeff0(fx, fy, fz);

    final halfW = size.width * .5;
    final halfH = size.height * .5;
    final focal = halfH / math.tan(_verticalFovDegrees * math.pi / 360.0);

    final h00 = halfW * czX + focal * cxX;
    final h01 = halfW * czY + focal * cxY;
    final h02 = halfW * cz0 + focal * cx0;
    final h10 = halfH * czX - focal * cyX;
    final h11 = halfH * czY - focal * cyY;
    final h12 = halfH * cz0 - focal * cy0;
    final h20 = czX;
    final h21 = czY;
    final h22 = cz0;

    // Matrix4 storage is column-major. z is unused; row 3 is the homogeneous
    // denominator, which makes this an exact homography for the y=0 pitch.
    widget.onProjectionChanged?.call(<double>[
      h00, h10, 0.0, h20,
      h01, h11, 0.0, h21,
      0.0, 0.0, 1.0, 0.0,
      h02, h12, 0.0, h22,
    ]);
  }

  void _updateViewport(Size size) {
    if (size.width <= 1 || size.height <= 1) return;
    if ((_viewportSize.width - size.width).abs() < .5 &&
        (_viewportSize.height - size.height).abs() < .5) return;
    _viewportSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _applyCameraProjection();
      _emitProjectionMatrix();
    });
  }

  void _orbitBy(Offset delta) {
    _orbitYaw -= delta.dx * 0.0070;
    // Keep the eye above the stadium roof. The full model is about 37 m high;
    // a low orbit can move the camera behind/inside the bowl and show the
    // back-faces as a black wall instead of the pitch.
    _orbitPitch = (_orbitPitch + delta.dy * 0.0055)
        .clamp(1.25, 1.52)
        .toDouble();
    _applyOrbitCamera();
  }

  void _zoomBy(double factor) {
    // Zoom with lens FOV instead of moving the camera through the stands.
    // This keeps the full stadium model intact and prevents the field from
    // disappearing behind the bowl at large zoom-out values.
    final delta = factor > 1.0 ? 4.0 : -4.0;
    _verticalFovDegrees = (_verticalFovDegrees + delta)
        .clamp(34.0, 90.0)
        .toDouble();
    _applyOrbitCamera();
  }

  void _resetCamera() {
    _orbitYaw = 0.0;
    _orbitPitch = 1.36;
    _orbitRadius = 100.0;
    _verticalFovDegrees = 66.0;
    _endOrbitPointer();
    _applyOrbitCamera();
  }

  bool _isExternalOrbitButton(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return false;
    const mask = kSecondaryMouseButton | kMiddleMouseButton;
    return (e.buttons & mask) != 0;
  }

  void _onExternalPointerDown(PointerDownEvent e) {
    if (!_isExternalOrbitButton(e)) return;
    _orbitDragging = true;
    _orbitPointer = e.pointer;
    _orbitButtons = e.buttons & (kSecondaryMouseButton | kMiddleMouseButton);
    _lastPointerPosition = e.localPosition;
  }

  void _onExternalPointerMove(PointerMoveEvent e) {
    if (!_orbitDragging || _orbitPointer != e.pointer) return;
    if (_orbitButtons == 0 || (e.buttons & _orbitButtons) == 0) {
      _endOrbitPointer();
      return;
    }
    final previous = _lastPointerPosition;
    _lastPointerPosition = e.localPosition;
    if (previous == null) return;
    _orbitBy(e.localPosition - previous);
  }

  void _onExternalPointerUp(PointerUpEvent e) {
    if (_orbitPointer == e.pointer) _endOrbitPointer();
  }

  void _onExternalPointerCancel(PointerCancelEvent e) {
    if (_orbitPointer == e.pointer) _endOrbitPointer();
  }

  void _onExternalPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    _zoomBy(e.scrollDelta.dy > 0 ? 1.08 : .92);
  }

  bool _isOrbitPointerAllowed(PointerDownEvent e) {
    // Touch/stylus events do not use the desktop button bitmask. For a mouse,
    // rotate only with the primary button held down.
    if (e.kind == PointerDeviceKind.mouse) {
      return (e.buttons & kPrimaryMouseButton) != 0;
    }
    return true;
  }

  void _onOrbitPointerDown(PointerDownEvent e) {
    if (!widget.enableCameraInput) return;
    if (!_isOrbitPointerAllowed(e)) return;
    _orbitDragging = true;
    _orbitPointer = e.pointer;
    _lastPointerPosition = e.localPosition;
  }

  void _onOrbitPointerMove(PointerMoveEvent e) {
    if (!widget.enableCameraInput) return;
    if (!_orbitDragging || _orbitPointer != e.pointer) return;

    // On desktop an Up can occasionally be lost by a platform texture. The
    // current button mask is therefore an additional guard: the very first
    // move after release terminates the orbit session instead of continuing.
    if (e.kind == PointerDeviceKind.mouse &&
        (e.buttons & kPrimaryMouseButton) == 0) {
      _endOrbitPointer();
      return;
    }

    final previous = _lastPointerPosition;
    _lastPointerPosition = e.localPosition;
    if (previous == null) return;

    _orbitBy(e.localPosition - previous);
  }

  void _onOrbitPointerSignal(PointerSignalEvent e) {
    if (!widget.enableCameraInput) return;
    if (e is! PointerScrollEvent) return;
    _zoomBy(e.scrollDelta.dy > 0 ? 1.08 : .92);
  }

  void _endOrbitPointer() {
    _orbitDragging = false;
    _orbitPointer = null;
    _orbitButtons = 0;
    _lastPointerPosition = null;
  }

  void _safeSetViewerState(VoidCallback update) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(update);
    });
  }

  Future<void> _onViewerAvailable(thermion.ThermionViewer viewer) async {
    try {
      // Explicit light directions are important for a wide horizontal pitch.
      // The generic SUN from ViewerWidget can leave the grass nearly black.
      await viewer.addDirectLight(
        thermion.DirectLight.sun(
          direction: thermion.Vector3(-0.20, -1.0, -0.18),
          intensity: 155000,
          castShadows: true,
        ),
      );
      await viewer.addDirectLight(
        thermion.DirectLight.sun(
          direction: thermion.Vector3(0.35, -0.75, 0.22),
          intensity: 65000,
          castShadows: false,
        ),
      );

      _camera = await viewer.getActiveCamera();
      await _applyOrbitCamera();

      _safeSetViewerState(() {
        _viewerReady = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewerReady = true;
        _error = 'Не удалось подготовить 3D-поле: $e';
      });
    }
  }

  @override
  void deactivate() {
    _endOrbitPointer();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _endOrbitPointer();
    _camera = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateViewport(Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onOrbitPointerDown,
            onPointerMove: _onOrbitPointerMove,
            onPointerUp: (_) => _endOrbitPointer(),
            onPointerCancel: (_) => _endOrbitPointer(),
            onPointerSignal: _onOrbitPointerSignal,
            child: thermion.ViewerWidget(
              assetPath: 'assets/training/3d/stadium_full.glb',
              transformToUnitCube: false,
              initialCameraPosition: thermion.Vector3(0, 97.8, 20.9),
              background: const Color(0xFF26463A),
              // Camera gestures are handled by the Listener above. Disabling
              // Thermion's built-in manipulator fixes the macOS "mouse stays
              // pressed" behaviour and gives us predictable button release.
              manipulatorType: thermion.ManipulatorType.NONE,
              postProcessing: true,
              onViewerAvailable: _onViewerAvailable,
              initial: Container(
                color: const Color(0xFF26463A),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF61D69D),
                      strokeWidth: 2.4,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Загрузка поля…',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showStatusBadge)
          Positioned(
            left: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1915).withOpacity(.76),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                ),
                child: Text(
                  _viewerReady
                      ? '3D поле · ПКМ/средняя — вращение · колесо — масштаб'
                      : '3D поле',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101B17).withOpacity(.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
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

/// Kept only for old call sites outside TrainingGraphicsScreen. The main
/// editor no longer navigates here; it embeds [TrainingGraphicsGlbFieldView].
class TrainingGraphicsGameViewScreen extends StatelessWidget {
  const TrainingGraphicsGameViewScreen({
    super.key,
    required this.state,
    this.title = '3D поле',
    this.onTogglePlayback,
    this.playbackRunning = false,
  });

  final TgState state;
  final String title;
  final VoidCallback? onTogglePlayback;
  final bool playbackRunning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10231C),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: TrainingGraphicsGlbFieldView(
                state: state,
                onTogglePlayback: onTogglePlayback,
                playbackRunning: playbackRunning,
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Material(
                color: const Color(0xFF101B17).withOpacity(.90),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
