import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

/// Universal mobile stadium renderer for Android + iOS.
class UniversalMobileStadiumView extends StatefulWidget {
  const UniversalMobileStadiumView({
    super.key,
    required this.assetPath,
  });

  final String assetPath;

  @override
  State<UniversalMobileStadiumView> createState() =>
      _UniversalMobileStadiumViewState();
}

class _UniversalMobileStadiumViewState
    extends State<UniversalMobileStadiumView> {
  late final three.ThreeJS _threeJs;
  three.OrbitControls? _controls;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    debugPrint('[STADIUM_MOBILE_3JS] init asset=${widget.assetPath}');

    _threeJs = three.ThreeJS(
      settings: three.Settings(
        antialias: true,
        enableShadowMap: true,
        clearColor: 0x18382C,
        clearAlpha: 1.0,
      ),
      loadingWidget: const ColoredBox(
        color: Color(0xFF18382C),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF61D69D),
            strokeWidth: 2.4,
          ),
        ),
      ),
      setup: _setupScene,
      onSetupComplete: () {
        if (!mounted) return;
        setState(() => _ready = true);
        debugPrint('[STADIUM_MOBILE_3JS] READY asset=${widget.assetPath}');
      },
    );
  }

  @override
  void dispose() {
    _controls?.dispose();
    _threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  Future<void> _setupScene() async {
    try {
      _threeJs.scene = three.Scene();
      _threeJs.scene.background = three.Color.fromHex32(0x18382C);

      _threeJs.camera = three.PerspectiveCamera(
        42,
        _safeAspect(),
        0.1,
        1000000,
      );

      _addLights();

      final loader = three.GLTFLoader(flipY: true);
      final gltf = await loader.fromAsset(widget.assetPath);

      if (gltf == null) {
        throw StateError('Не удалось загрузить ${widget.assetPath}');
      }

      final model = gltf.scene;

      model.traverse((three.Object3D object) {
        if (object is three.Mesh) {
          object.castShadow = true;
          object.receiveShadow = true;
        }
      });

      _threeJs.scene.add(model);

      final box = three.BoundingBox()..setFromObject(model);
      final center = box.getCenter(three.Vector3());
      final size = box.getSize(three.Vector3());

      final dims = <double>[size.x.abs(), size.y.abs(), size.z.abs()];
      final maxDim = dims.reduce((a, b) => a > b ? a : b);
      final safeDim = maxDim.isFinite && maxDim > 0.001 ? maxDim : 10.0;

      final camera = _threeJs.camera as three.PerspectiveCamera;
      camera.position.setValues(
        center.x + safeDim * 0.72,
        center.y + safeDim * 0.52,
        center.z + safeDim * 0.92,
      );
      camera.lookAt(center);

      _controls = three.OrbitControls(
        _threeJs.camera,
        _threeJs.globalKey,
      )
        ..enableDamping = true
        ..dampingFactor = 0.07
        ..rotateSpeed = 0.62
        ..zoomSpeed = 0.86
        ..screenSpacePanning = false
        ..minDistance = safeDim * 0.08
        ..maxDistance = safeDim * 6.0;

      _controls!.target.setValues(center.x, center.y, center.z);
      _controls!.update();

      _threeJs.addAnimationEvent((double dt) {
        _controls?.update();
      });

      debugPrint(
        '[STADIUM_MOBILE_3JS] model loaded '
        'asset=${widget.assetPath} '
        'center=(${center.x},${center.y},${center.z}) '
        'size=(${size.x},${size.y},${size.z}) '
        'maxDim=$safeDim',
      );
    } catch (e, st) {
      debugPrint('[STADIUM_MOBILE_3JS] ERROR $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  double _safeAspect() {
    final h = _threeJs.height;
    final w = _threeJs.width;
    if (h <= 0 || w <= 0) return 1.5;
    return w / h;
  }

  void _addLights() {
    _threeJs.scene.add(three.AmbientLight(0xFFFFFF, 1.35));

    final key = three.DirectionalLight(0xFFFFFF, 2.15);
    key.position.setValues(-40, 90, 55);
    key.castShadow = true;
    _threeJs.scene.add(key);

    final fill = three.DirectionalLight(0xDDF5E8, 1.25);
    fill.position.setValues(65, 45, -45);
    _threeJs.scene.add(fill);

    final rim = three.DirectionalLight(0xFFFFFF, 0.80);
    rim.position.setValues(0, 75, 90);
    _threeJs.scene.add(rim);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF18382C),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось открыть 3D-стадион\n$_error',
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _threeJs.build(),
        if (!_ready)
          const IgnorePointer(
            child: ColoredBox(color: Color(0x3318382C)),
          ),
      ],
    );
  }
}
