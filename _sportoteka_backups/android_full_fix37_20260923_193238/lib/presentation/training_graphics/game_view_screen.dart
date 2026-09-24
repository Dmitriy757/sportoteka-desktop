// lib/presentation/training_graphics/game_view_screen.dart
// Sportoteka Training Graphics — inline GLB field mode on Thermion/Filament.
// The 3D renderer is an additional field/view mode inside the editor.

import 'dart:async';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as thermion;
import 'package:sportoteka_stadium_android/sportoteka_stadium_android.dart'
    as native_stadium;

import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';

enum TrainingGraphics3DCameraPreset { overview, tv, stand, goal, free }

class TrainingGraphicsGlbFieldController {
  _TrainingGraphicsGlbFieldViewState? _state;

  /// Normalized camera focus on the football pitch: dx = length, dy = width.
  final ValueNotifier<Offset> radarFocus = ValueNotifier<Offset>(const Offset(.5, .5));
  final ValueNotifier<double> radarYaw = ValueNotifier<double>(0.0);

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
  void panBy(Offset delta) => _state?._panBy(delta);
  void handleTabletGesture({
    Offset panDelta = Offset.zero,
    double zoomFactor = 1.0,
    double yawDelta = 0.0,
  }) => _state?._handleTabletGesture(
        panDelta: panDelta,
        zoomFactor: zoomFactor,
        yawDelta: yawDelta,
      );
  void zoomIn() => _state?._zoomBy(.90);
  void zoomOut() => _state?._zoomBy(1.10);
  void reset() => _state?._resetCamera();
  void setPreset(TrainingGraphics3DCameraPreset preset) =>
      _state?._setCameraPreset(preset);
  void focusAtNormalized(double u, double v) =>
      _state?._focusAtNormalized(u, v);
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
    this.fieldVariant = 1,
    this.onCameraChanged,
    this.onProjectionChanged,
  });

  final TgState state;
  final VoidCallback? onTogglePlayback;
  final bool playbackRunning;
  final bool enableCameraInput;
  final bool showStatusBadge;
  final TrainingGraphicsGlbFieldController? controller;
  final int fieldVariant;
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

  // Android uses a native Google Filament SurfaceView rather than Thermion's
  // Flutter TextureRegistry path. This avoids the blank-surface/swapchain
  // lifecycle problems seen on real Android tablets with Impeller.
  bool _androidCompatibilityReady = true;
  bool _androidArm64Supported = true;
  String? _androidAbiSummary;
  String? _androidDeviceSummary;
  Timer? _androidStartupTimer;
  int _viewerGeneration = 0;
  native_stadium.SportotekaAndroidStadiumController? _androidNativeController;
  // Native TextureView composes correctly under the Flutter tactical overlay.
  // If a device cannot start it, retry once with a native SurfaceView.
  bool _androidUseNativeTextureView = true;
  bool _androidNativeFallbackTried = false;

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
  double _verticalFovDegrees = 74.0;
  int _orbitButtons = 0;
  bool _panDragging = false;
  double _focusX = 0.0;
  double _focusZ = 0.0;
  Size _viewportSize = Size.zero;

  static const double _logicalFieldLength = 1050.0;
  static const double _logicalFieldWidth = 680.0;

  bool get _isSecondStadium => widget.fieldVariant == 1;
  bool get _isThirdStadium => widget.fieldVariant == 3;

  String? _resolvedAndroidAssetPath;
  List<String> _availableAndroidAssets = const [];
  bool _androidAssetReady = true;

  List<String> get _androidAssetCandidates {
    switch (widget.fieldVariant) {
      case 1:
        return const [
          'assets/training/3d/stadium1_android.glb',
          'assets/training/3d/stadium2_full.glb',
        ];
      case 2:
        return const [
          'assets/training/3d/stadium2_android.glb',
          'assets/training/3d/stadium_full.glb',
        ];
      case 3:
        return const [
          'assets/training/3d/stadium3_android.glb',
          'assets/training/3d/stadium3_full.glb',
        ];
      default:
        return const [
          'assets/training/3d/stadium1_android.glb',
          'assets/training/3d/stadium2_full.glb',
        ];
    }
  }

  String get _desktopAssetPath {
    switch (widget.fieldVariant) {
      case 1:
        return 'assets/training/3d/stadium2_full.glb';
      case 2:
        return 'assets/training/3d/stadium_full.glb';
      case 3:
        return 'assets/training/3d/stadium3_full.glb';
      default:
        return 'assets/training/3d/stadium2_full.glb';
    }
  }

  String get _assetPath => _isAndroidPlatform
      ? (_resolvedAndroidAssetPath ?? _androidAssetCandidates.first)
      : _desktopAssetPath;

  // Each imported stadium uses its own native coordinate system. The tactical
  // editor remains 1050x680 logical units; these values map that plane exactly
  // onto the visible grass in each GLB.
  double get _worldFieldLength {
    if (_isSecondStadium) return 1050.0;
    if (_isThirdStadium) return 22.4999551;
    return 113.4514428;
  }

  double get _worldFieldWidth {
    if (_isSecondStadium) return 680.0;
    if (_isThirdStadium) return 12.9999740;
    return 75.6843148;
  }

  double get _worldFieldCenterX {
    if (_isSecondStadium) return -1.05;
    if (_isThirdStadium) return -0.0018222;
    return 0.0;
  }

  double get _worldFieldCenterZ {
    if (_isSecondStadium) return -6.9;
    if (_isThirdStadium) return -0.0010528;
    return 0.0;
  }

  double get _worldFieldPlaneY {
    if (_isSecondStadium) return 35.86;
    if (_isThirdStadium) return -0.0825509;
    return 0.0;
  }
  bool get _lengthRunsAlongWorldX => _isSecondStadium || _isThirdStadium;
  double get _cameraScale => _worldFieldLength / 113.4514428;

  @override
  void initState() {
    super.initState();
    _applyFieldVariantDefaults();
    widget.controller?._attach(this);
    _androidCompatibilityReady = !_isAndroidPlatform;
    _androidAssetReady = !_isAndroidPlatform;
    if (_isAndroidPlatform) {
      unawaited(_prepareAndroidStartup());
    }
  }

  @override
  void didUpdateWidget(covariant TrainingGraphicsGlbFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.fieldVariant != widget.fieldVariant) {
      _camera = null;
      _androidNativeController = null;
      _viewerReady = false;
      _error = null;
      _endOrbitPointer();
      _applyFieldVariantDefaults();
      if (_isAndroidPlatform && _androidArm64Supported) {
        _resolvedAndroidAssetPath = null;
        _androidAssetReady = false;
        _androidUseNativeTextureView = true;
        _androidNativeFallbackTried = false;
        unawaited(_resolveAndroidAssetPath());
      }
    }
  }

  Future<void> _prepareAndroidStartup() async {
    await Future.wait<void>([
      _prepareAndroidCompatibility(),
      _resolveAndroidAssetPath(),
    ]);
  }

  Future<void> _resolveAndroidAssetPath() async {
    if (!_isAndroidPlatform) return;

    final candidates = _androidAssetCandidates;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      final available = candidates.where((path) => assets.contains(path)).toList();
      final selected = available.isEmpty ? null : available.first;

      if (!mounted) return;
      _safeSetViewerState(() {
        _availableAndroidAssets = available;
        _resolvedAndroidAssetPath = selected;
        _androidAssetReady = selected != null;
        if (selected == null) {
          _viewerReady = true;
          _error = 'Не найден файл 3D-стадиона в Android assets. '
              'Проверены: ${candidates.join(', ')}.';
        } else {
          _viewerReady = false;
          _error = null;
        }
      });
      if (selected != null) {
        _scheduleAndroidStartupWatchdog();
      }
    } catch (e) {
      if (!mounted) return;
      _safeSetViewerState(() {
        // AssetManifest is only a preflight. If it cannot be read, let the
        // native loader try the preferred Android asset rather than blocking.
        _availableAndroidAssets = candidates;
        _resolvedAndroidAssetPath = candidates.first;
        _androidAssetReady = true;
        _error = null;
      });
      _scheduleAndroidStartupWatchdog();
      debugPrint('Android stadium asset preflight: $e');
    }
  }

  Future<void> _prepareAndroidCompatibility() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;
      final arm64 = abis.any((abi) => abi.toLowerCase() == 'arm64-v8a');
      final manufacturer = info.manufacturer.trim();
      final model = info.model.trim();

      if (!mounted) return;
      _safeSetViewerState(() {
        _androidCompatibilityReady = true;
        _androidArm64Supported = arm64;
        _androidAbiSummary = abis.isEmpty ? 'не определён' : abis.join(', ');
        _androidDeviceSummary = [manufacturer, model]
            .where((part) => part.isNotEmpty)
            .join(' ');
        if (!arm64) {
          _viewerReady = true;
          _error = '3D-стадионы требуют Android ARM64 (arm64-v8a). '
              'На этом устройстве: ${_androidAbiSummary ?? 'ABI не определён'}.';
        }
      });
      if (arm64) {
        _androidUseNativeTextureView = true;
        _androidNativeFallbackTried = false;
        _scheduleAndroidStartupWatchdog();
      }
    } catch (_) {
      // Device-info is diagnostic only; never block a compatible tablet when
      // the probe itself is unavailable. Native Filament will report a real
      // renderer error through the PlatformView channel if startup fails.
      if (!mounted) return;
      _safeSetViewerState(() {
        _androidCompatibilityReady = true;
        _androidArm64Supported = true;
      });
      _androidUseNativeTextureView = true;
      _androidNativeFallbackTried = false;
      _scheduleAndroidStartupWatchdog();
    }
  }

  void _scheduleAndroidStartupWatchdog() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _armAndroidStartupWatchdog();
    });
  }

  double get _cameraNearPlane =>
      _isThirdStadium ? 0.02 : (_isSecondStadium ? 0.5 : 0.05);

  double get _cameraFarPlane =>
      _isThirdStadium ? 600.0 : (_isSecondStadium ? 6500.0 : 2200.0);

  void _armAndroidStartupWatchdog() {
    _androidStartupTimer?.cancel();
    if (!_isAndroidPlatform ||
        !_androidCompatibilityReady ||
        !_androidArm64Supported ||
        !_androidAssetReady) {
      return;
    }
    _androidStartupTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || _viewerReady) return;

      // First retry changes only the native Android presentation view. This is
      // not Flutter TextureRegistry: both paths render Filament natively.
      if (!_androidNativeFallbackTried) {
        _androidNativeFallbackTried = true;
        _androidUseNativeTextureView = !_androidUseNativeTextureView;
        _androidNativeController = null;
        _safeSetViewerState(() {
          _viewerGeneration += 1;
          _viewerReady = false;
          _error = null;
        });
        _armAndroidStartupWatchdog();
        return;
      }

      final mode = _androidUseNativeTextureView
          ? 'native TextureView'
          : 'native SurfaceView';
      _safeSetViewerState(() {
        _error = 'Нативный Android Filament не запустил 3D-стадион. '
            '${_androidDeviceSummary?.isNotEmpty == true ? '${_androidDeviceSummary!}. ' : ''}'
            'ABI: ${_androidAbiSummary ?? 'не определён'}. '
            'Последний режим: $mode. Нажмите «Повторить».';
      });
    });
  }

  void _retryAndroidRenderer() {
    _androidStartupTimer?.cancel();
    _camera = null;
    _androidNativeController = null;
    _endOrbitPointer();
    if (_isAndroidPlatform && !_androidAssetReady) {
      setState(() {
        _viewerReady = false;
        _error = null;
      });
      unawaited(_resolveAndroidAssetPath());
      return;
    }
    if (_isAndroidPlatform) {
      _androidUseNativeTextureView = !_androidUseNativeTextureView;
      _androidNativeFallbackTried = true;
    }
    setState(() {
      _viewerGeneration += 1;
      _viewerReady = false;
      _error = null;
    });
    _armAndroidStartupWatchdog();
  }

  void _applyFieldVariantDefaults() {
    _orbitYaw = 0.0;
    _focusX = _worldFieldCenterX;
    _focusZ = _worldFieldCenterZ;
    if (_isSecondStadium) {
      // Stadium 2 opens from the stand by default.
      _orbitYaw = math.pi / 2;
      _orbitPitch = .74;
      _orbitRadius = 66.0 * _cameraScale;
      _verticalFovDegrees = 50.0;
    } else if (_isThirdStadium) {
      // Stadium 3 replacement is a compact native model (pitch ~22.5 x 13).
      // Start from a useful overview that keeps the surrounding structures in frame.
      _orbitYaw = .30;
      _orbitPitch = 1.15;
      _orbitRadius = 22.0;
      _verticalFovDegrees = 60.0;
    } else {
      // Stadium 1 opens from the stand by default as requested.
      _orbitYaw = math.pi / 2;
      _orbitPitch = .74;
      _orbitRadius = 66.0 * _cameraScale;
      _verticalFovDegrees = 50.0;
    }
  }

  void _notifyRadar() {
    final controller = widget.controller;
    if (controller == null) return;
    double u;
    double v;
    if (_lengthRunsAlongWorldX) {
      u = (_focusX - (_worldFieldCenterX - _worldFieldLength * .5)) / _worldFieldLength;
      v = (_focusZ - (_worldFieldCenterZ - _worldFieldWidth * .5)) / _worldFieldWidth;
    } else {
      u = (_focusZ - (_worldFieldCenterZ - _worldFieldLength * .5)) / _worldFieldLength;
      v = (_focusX - (_worldFieldCenterX - _worldFieldWidth * .5)) / _worldFieldWidth;
    }
    controller.radarFocus.value = Offset(
      u.clamp(0.0, 1.0).toDouble(),
      v.clamp(0.0, 1.0).toDouble(),
    );
    controller.radarYaw.value = _orbitYaw;
  }

  void _focusAtNormalized(double u, double v) {
    final nu = u.clamp(0.0, 1.0).toDouble();
    final nv = v.clamp(0.0, 1.0).toDouble();
    if (_lengthRunsAlongWorldX) {
      _focusX = _worldFieldCenterX + (nu - .5) * _worldFieldLength;
      _focusZ = _worldFieldCenterZ + (nv - .5) * _worldFieldWidth;
    } else {
      _focusZ = _worldFieldCenterZ + (nu - .5) * _worldFieldLength;
      _focusX = _worldFieldCenterX + (nv - .5) * _worldFieldWidth;
    }
    _applyOrbitCamera();
  }

  Future<void> _applyOrbitCamera() async {
    _notifyRadar();

    final horizontal = _orbitRadius * math.cos(_orbitPitch);
    final eyeX = _focusX + horizontal * math.sin(_orbitYaw);
    final eyeY = _worldFieldPlaneY + _orbitRadius * math.sin(_orbitPitch);
    final eyeZ = _focusZ + horizontal * math.cos(_orbitYaw);

    if (_isAndroidPlatform) {
      final controller = _androidNativeController;
      if (controller != null) {
        try {
          await controller.setCamera(
            eyeX: eyeX,
            eyeY: eyeY,
            eyeZ: eyeZ,
            targetX: _focusX,
            targetY: _worldFieldPlaneY,
            targetZ: _focusZ,
            verticalFovDegrees: _verticalFovDegrees,
            nearPlane: _cameraNearPlane,
            farPlane: _cameraFarPlane,
          );
        } catch (e) {
          debugPrint('Native Android stadium camera: $e');
        }
      }
      _emitProjectionMatrix();
      widget.onCameraChanged?.call(_orbitYaw, _orbitPitch, _orbitRadius);
      return;
    }

    final camera = _camera;
    if (camera == null) return;
    await camera.lookAt(
      thermion.Vector3(eyeX, eyeY, eyeZ),
      focus: thermion.Vector3(_focusX, _worldFieldPlaneY, _focusZ),
    );
    await _applyCameraProjection();
    _emitProjectionMatrix();
    widget.onCameraChanged?.call(_orbitYaw, _orbitPitch, _orbitRadius);
  }

  Future<void> _applyCameraProjection() async {
    if (_isAndroidPlatform) return;
    final camera = _camera;
    final size = _viewportSize;
    if (camera == null || size.width <= 1 || size.height <= 1) return;
    final aspect = size.width / size.height;
    try {
      await camera.setProjectionFromVerticalFieldOfView(
        _verticalFovDegrees,
        _cameraNearPlane,
        _cameraFarPlane,
        aspect,
      );
    } catch (_) {
      // Keep rendering even on an older desktop camera implementation.
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
    final px = _focusX + _orbitRadius * cp * sy;
    final py = _worldFieldPlaneY + _orbitRadius * sp;
    final pz = _focusZ + _orbitRadius * cp * cy;

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

    // Logical scene -> the native pitch plane. Stadium 1 stores pitch length
    // along world Z; Stadium 2 stores it along world X.
    final lengthScale = _worldFieldLength / _logicalFieldLength;
    final widthScale = _worldFieldWidth / _logicalFieldWidth;
    final cwy = _worldFieldPlaneY;

    final cwx = _lengthRunsAlongWorldX
        ? _worldFieldCenterX - _worldFieldLength * .5
        : _worldFieldCenterX - _worldFieldWidth * .5;
    final cwz = _lengthRunsAlongWorldX
        ? _worldFieldCenterZ - _worldFieldWidth * .5
        : _worldFieldCenterZ - _worldFieldLength * .5;

    double coeffX(double qx, double qy, double qz) => _lengthRunsAlongWorldX
        ? qx * lengthScale
        : qz * lengthScale;
    double coeffY(double qx, double qy, double qz) => _lengthRunsAlongWorldX
        ? qz * widthScale
        : qx * widthScale;
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
    // Manual orbit is intentionally broader than the old stadium-safe clamp.
    // The camera still looks at the pitch centre, so the full model stays
    // usable while the user can reach TV/stand-like angles.
    final minPitch = _isSecondStadium ? 0.76 : (_isThirdStadium ? 0.62 : 0.68);
    _orbitPitch = (_orbitPitch + delta.dy * 0.0055)
        .clamp(minPitch, 1.48)
        .toDouble();
    _applyOrbitCamera();
  }

  void _panBy(Offset delta) {
    final size = _viewportSize;
    if (size.width <= 1 || size.height <= 1) return;

    // World-units per screen pixel at the current dolly distance. This keeps
    // panning natural both when zoomed in and when looking at the full pitch.
    final visibleHeight = 2.0 * _orbitRadius *
        math.tan(_verticalFovDegrees * math.pi / 360.0);
    final worldPerPixel = (visibleHeight / size.height)
        .clamp(.015 * _cameraScale, .55 * _cameraScale)
        .toDouble();

    final sy = math.sin(_orbitYaw);
    final cy = math.cos(_orbitYaw);

    // Ground-plane camera right vector = (cos(yaw), -sin(yaw)). Dragging the
    // view to the right moves the camera/focus to the left, like a hand tool.
    final dx = delta.dx * worldPerPixel;
    final dy = delta.dy * worldPerPixel;
    _focusX -= cy * dx;
    _focusZ += sy * dx;

    // Vertical drag moves along the pitch direction currently facing the user.
    _focusX += sy * dy;
    _focusZ += cy * dy;

    // Allow the camera to travel across the whole pitch and slightly beyond
    // the touchlines/goal lines, but never lose the stadium completely.
    final maxX = _lengthRunsAlongWorldX
        ? _worldFieldLength * .42
        : _worldFieldWidth * .44;
    final maxZ = _lengthRunsAlongWorldX
        ? _worldFieldWidth * .44
        : _worldFieldLength * .42;
    _focusX = _focusX
        .clamp(_worldFieldCenterX - maxX, _worldFieldCenterX + maxX)
        .toDouble();
    _focusZ = _focusZ
        .clamp(_worldFieldCenterZ - maxZ, _worldFieldCenterZ + maxZ)
        .toDouble();

    _applyOrbitCamera();
  }

  void _handleTabletGesture({
    Offset panDelta = Offset.zero,
    double zoomFactor = 1.0,
    double yawDelta = 0.0,
  }) {
    // Tablet gestures are deliberately split from one-finger editing:
    // two-finger translation flies across the pitch, pinch dollies the real
    // 3D camera and a two-finger twist changes yaw. Pitch remains available on
    // the visible camera joystick so drawing never fights with camera tilt.
    if (panDelta.distanceSquared > .01) {
      _panBy(panDelta);
    }
    if ((zoomFactor - 1.0).abs() > .002) {
      _zoomBy(zoomFactor.clamp(.82, 1.22).toDouble());
    }
    if (yawDelta.abs() > .001) {
      _orbitYaw -= yawDelta;
      _applyOrbitCamera();
    }
  }

  void _zoomBy(double factor) {
    // Dolly the real 3D camera instead of only changing its projection/FOV.
    // This makes the GLB and the tactical overlay move together and prevents
    // wheel input from feeling like it only changes object sizes.
    final double minRadius;
    final double maxRadius;
    if (_isThirdStadium) {
      minRadius = _orbitPitch < .90 ? 9.5 : 8.0;
      maxRadius = 42.0;
    } else {
      final baseMinRadius = _orbitPitch < .90 ? 48.0 : 40.0;
      minRadius = baseMinRadius * _cameraScale;
      maxRadius = 190.0 * _cameraScale;
    }
    _orbitRadius = (_orbitRadius * factor)
        .clamp(minRadius, maxRadius)
        .toDouble();
    _applyOrbitCamera();
  }

  void _setCameraPreset(TrainingGraphics3DCameraPreset preset) {
    // Presets always frame the pitch centre. After applying one, the user can
    // immediately pan anywhere with Shift+RMB or the middle mouse button.
    _focusX = _worldFieldCenterX;
    _focusZ = _worldFieldCenterZ;
    switch (preset) {
      case TrainingGraphics3DCameraPreset.overview:
        if (_isThirdStadium) {
          _orbitYaw = .30;
          _orbitPitch = 1.15;
          _orbitRadius = 22.0;
          _verticalFovDegrees = 60.0;
        } else {
          _orbitYaw = 0.0;
          _orbitPitch = 1.34;
          _orbitRadius = 108.0 * _cameraScale;
          _verticalFovDegrees = 66.0;
        }
        break;
      case TrainingGraphics3DCameraPreset.tv:
        _orbitYaw = math.pi / 2;
        if (_isSecondStadium) {
          // Stadium 2: move the TV camera well inside the bowl so the stand
          // does not dominate the foreground. A slightly higher pitch keeps
          // the whole useful part of the grass visible.
          _orbitPitch = .86;
          _orbitRadius = 50.0 * _cameraScale;
          _verticalFovDegrees = 47.0;
        } else if (_isThirdStadium) {
          _orbitYaw = 0.0;
          _orbitPitch = .78;
          _orbitRadius = 15.5;
          _verticalFovDegrees = 50.0;
        } else {
          _orbitPitch = .92;
          _orbitRadius = 78.0 * _cameraScale;
          _verticalFovDegrees = 54.0;
        }
        break;
      case TrainingGraphics3DCameraPreset.stand:
        _orbitYaw = math.pi / 2;
        if (_isThirdStadium) {
          _orbitYaw = 0.0;
          _orbitPitch = .68;
          _orbitRadius = 14.5;
          _verticalFovDegrees = 48.0;
        } else {
          _orbitPitch = .74;
          _orbitRadius = 66.0 * _cameraScale;
          _verticalFovDegrees = 50.0;
        }
        break;
      case TrainingGraphics3DCameraPreset.goal:
        _orbitYaw = 0.0;
        if (_isThirdStadium) {
          _orbitYaw = math.pi / 2;
          _orbitPitch = .72;
          _orbitRadius = 16.0;
          _verticalFovDegrees = 50.0;
        } else {
          _orbitPitch = .72;
          _orbitRadius = 72.0 * _cameraScale;
          _verticalFovDegrees = 50.0;
        }
        break;
      case TrainingGraphics3DCameraPreset.free:
        _orbitYaw = -.58;
        if (_isThirdStadium) {
          _orbitYaw = -.65;
          _orbitPitch = .95;
          _orbitRadius = 18.0;
          _verticalFovDegrees = 56.0;
        } else {
          _orbitPitch = 1.08;
          _orbitRadius = 88.0 * _cameraScale;
          _verticalFovDegrees = 58.0;
        }
        break;
    }
    _endOrbitPointer();
    _applyOrbitCamera();
  }

  void _resetCamera() {
    _setCameraPreset(
      _isThirdStadium
          ? TrainingGraphics3DCameraPreset.overview
          : TrainingGraphics3DCameraPreset.stand,
    );
  }

  bool _isExternalCameraButton(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse) return false;
    const mask = kSecondaryMouseButton | kMiddleMouseButton;
    return (e.buttons & mask) != 0;
  }

  void _onExternalPointerDown(PointerDownEvent e) {
    if (!_isExternalCameraButton(e)) return;
    _orbitDragging = true;
    _orbitPointer = e.pointer;
    _orbitButtons = e.buttons & (kSecondaryMouseButton | kMiddleMouseButton);
    _lastPointerPosition = e.localPosition;

    // Middle button is always pan. Shift + right button is also pan, which is
    // convenient on macOS mice/trackpads where a middle button may not exist.
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
    _panDragging = (_orbitButtons & kMiddleMouseButton) != 0 ||
        (shiftPressed && (_orbitButtons & kSecondaryMouseButton) != 0);
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
    final delta = e.localPosition - previous;
    if (_panDragging) {
      _panBy(delta);
    } else {
      _orbitBy(delta);
    }
  }

  void _onExternalPointerUp(PointerUpEvent e) {
    if (_orbitPointer == e.pointer) _endOrbitPointer();
  }

  void _onExternalPointerCancel(PointerCancelEvent e) {
    if (_orbitPointer == e.pointer) _endOrbitPointer();
  }

  void _onExternalPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final steps = (e.scrollDelta.dy / 120.0).clamp(-3.0, 3.0).toDouble();
    final factor = math.pow(1.12, steps).toDouble();
    _zoomBy(factor);
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
    final steps = (e.scrollDelta.dy / 120.0).clamp(-3.0, 3.0).toDouble();
    final factor = math.pow(1.12, steps).toDouble();
    _zoomBy(factor);
  }

  void _endOrbitPointer() {
    _orbitDragging = false;
    _orbitPointer = null;
    _orbitButtons = 0;
    _panDragging = false;
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
      // Thermion is retained for macOS/desktop where it is already stable.
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
      _safeSetViewerState(() {
        _viewerReady = true;
        _error = 'Не удалось подготовить 3D-поле: $e';
      });
    }
  }

  void _onAndroidNativeCreated(
    native_stadium.SportotekaAndroidStadiumController controller,
  ) {
    _androidNativeController = controller;
    unawaited(_applyOrbitCamera());
  }

  void _onAndroidNativeReady() {
    _androidStartupTimer?.cancel();
    _safeSetViewerState(() {
      _viewerReady = true;
      _error = null;
    });
  }

  void _onAndroidNativeError(String message) {
    _androidStartupTimer?.cancel();

    final current = _resolvedAndroidAssetPath;
    final currentIndex = current == null
        ? -1
        : _availableAndroidAssets.indexOf(current);
    if (currentIndex >= 0 &&
        currentIndex + 1 < _availableAndroidAssets.length) {
      final fallback = _availableAndroidAssets[currentIndex + 1];
      _androidNativeController = null;
      _safeSetViewerState(() {
        _resolvedAndroidAssetPath = fallback;
        _viewerGeneration += 1;
        _viewerReady = false;
        _error = null;
      });
      _armAndroidStartupWatchdog();
      debugPrint(
        'Android stadium asset fallback: $current -> $fallback ($message)',
      );
      return;
    }

    _safeSetViewerState(() {
      _viewerReady = true;
      _error = 'Android Filament: $message';
    });
  }

  @override
  void deactivate() {
    _endOrbitPointer();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _androidStartupTimer?.cancel();
    _endOrbitPointer();
    _camera = null;
    _androidNativeController = null;
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
              child: (!_androidCompatibilityReady ||
                      !_androidAssetReady ||
                      !_androidArm64Supported)
                  ? Container(
                      color: const Color(0xFF26463A),
                      alignment: Alignment.center,
                      child: (_androidCompatibilityReady &&
                              _androidAssetReady)
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFF61D69D),
                                  strokeWidth: 2.4,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  !_androidCompatibilityReady
                                      ? 'Проверка Android 3D…'
                                      : 'Поиск модели стадиона…',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    )
                  : Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onOrbitPointerDown,
            onPointerMove: _onOrbitPointerMove,
            onPointerUp: (_) => _endOrbitPointer(),
            onPointerCancel: (_) => _endOrbitPointer(),
            onPointerSignal: _onOrbitPointerSignal,
            child: _isAndroidPlatform
                ? IgnorePointer(
                    child: native_stadium.SportotekaAndroidStadiumView(
                      key: ValueKey<String>(
                        'tg-native-android-${widget.fieldVariant}-$_viewerGeneration',
                      ),
                      assetPath: _assetPath,
                      eyeX: _focusX +
                          _orbitRadius *
                              math.cos(_orbitPitch) *
                              math.sin(_orbitYaw),
                      eyeY: _worldFieldPlaneY +
                          _orbitRadius * math.sin(_orbitPitch),
                      eyeZ: _focusZ +
                          _orbitRadius *
                              math.cos(_orbitPitch) *
                              math.cos(_orbitYaw),
                      targetX: _focusX,
                      targetY: _worldFieldPlaneY,
                      targetZ: _focusZ,
                      verticalFovDegrees: _verticalFovDegrees,
                      nearPlane: _cameraNearPlane,
                      farPlane: _cameraFarPlane,
                      useTextureView: _androidUseNativeTextureView,
                      backgroundColor: const Color(0xFF26463A),
                      onCreated: _onAndroidNativeCreated,
                      onReady: _onAndroidNativeReady,
                      onError: _onAndroidNativeError,
                    ),
                  )
                : thermion.ViewerWidget(
                    key: ValueKey<String>(
                      'tg-glb-field-${widget.fieldVariant}-$_viewerGeneration',
                    ),
                    assetPath: _assetPath,
                    transformToUnitCube: false,
                    initialCameraPosition: _isSecondStadium
                        ? thermion.Vector3(_worldFieldCenterX, 970.0, 250.0)
                        : (_isThirdStadium
                            ? thermion.Vector3(
                                _worldFieldCenterX,
                                22500.0,
                                6200.0,
                              )
                            : thermion.Vector3(0, 97.8, 20.9)),
                    background: const Color(0xFF26463A),
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
        if (!_isSecondStadium && !_isThirdStadium)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(.035),
                          Colors.transparent,
                          Colors.black.withOpacity(.24),
                        ],
                        stops: const [0.0, .48, 1.0],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-.18, -.12),
                        radius: 1.12,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(.16),
                        ],
                        stops: const [.60, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isAndroidPlatform &&
            _androidCompatibilityReady &&
            _androidArm64Supported &&
            !_viewerReady &&
            _error == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101B17).withOpacity(.88),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF61D69D),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Загрузка 3D стадиона…',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
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
                      ? (_isAndroidPlatform
                          ? '3D поле · Android Filament'
                          : '3D поле · ПКМ — вращение · Shift+ПКМ/средняя — движение · колесо — масштаб')
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
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF101B17).withOpacity(.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_isAndroidPlatform && _androidArm64Supported) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _retryAndroidRenderer,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ],
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
