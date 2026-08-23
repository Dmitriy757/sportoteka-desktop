import 'package:flutter/material.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/controls/OrbitControls.dart';

class Field3DScreen extends StatefulWidget {
  const Field3DScreen({super.key});

  @override
  State<Field3DScreen> createState() => _Field3DScreenState();
}

class _Field3DScreenState extends State<Field3DScreen> {
  late three.WebGLRenderer renderer;
  late three.Scene scene;
  late three.PerspectiveCamera camera;
  OrbitControls? controls;

  Size? _size;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final size = context.size ?? const Size(400, 700);
    _size = size;

    scene = three.Scene();
    scene.background = three.Color.fromHex32(0xFF0E141B);

    camera = three.PerspectiveCamera(55, size.width / size.height, 0.1, 5000);
    camera.position.setValues(0, 260, 420);

    renderer = three.WebGLRenderer(three.WebGLRendererParameters(antialias: true));
    renderer.setSize(size.width, size.height, false);

    // light
    final hemi = three.HemisphereLight(three.Color(0xffffff), three.Color(0x223344), 1.1);
    scene.add(hemi);

    final dir = three.DirectionalLight(three.Color(0xffffff), 0.9);
    dir.position.setValues(200, 300, 200);
    scene.add(dir);

    // field plane
    final fieldW = 600.0;
    final fieldH = 380.0;

    final planeGeo = three.PlaneGeometry(fieldW, fieldH);
    final planeMat = three.MeshStandardMaterial({
      "color": 0xFF1B7A3A, // зелёное поле
      "roughness": 0.95,
      "metalness": 0.0,
    });
    final plane = three.Mesh(planeGeo, planeMat);
    plane.rotation.x = -3.1415926 / 2;
    scene.add(plane);

    // lines (белая разметка)
    final lineMat = three.LineBasicMaterial({"color": 0xFFFFFFFF});
    final pts = <three.Vector3>[
      three.Vector3(-fieldW/2, 1, -fieldH/2),
      three.Vector3(fieldW/2, 1, -fieldH/2),
      three.Vector3(fieldW/2, 1, fieldH/2),
      three.Vector3(-fieldW/2, 1, fieldH/2),
      three.Vector3(-fieldW/2, 1, -fieldH/2),
    ];
    final geo = three.BufferGeometry().setFromPoints(pts);
    scene.add(three.Line(geo, lineMat));

    // center line
    final mid = three.BufferGeometry().setFromPoints([
      three.Vector3(-fieldW/2, 1, 0),
      three.Vector3(fieldW/2, 1, 0),
    ]);
    scene.add(three.Line(mid, lineMat));

    // center circle
    final circlePts = <three.Vector3>[];
    const seg = 64;
    const r = 55.0;
    for (int i = 0; i <= seg; i++) {
      final a = (i / seg) * 3.1415926 * 2;
      circlePts.add(three.Vector3(mathCos(a) * r, 1, mathSin(a) * r));
    }
    final circleGeo = three.BufferGeometry().setFromPoints(circlePts);
    scene.add(three.Line(circleGeo, lineMat));

    controls = OrbitControls(camera, renderer.domElement);
    controls!.enableDamping = true;
    controls!.target.setValues(0, 0, 0);

    setState(() => _ready = true);
    _animate();
  }

  void _animate() {
    if (!mounted || !_ready) return;
    controls?.update();
    renderer.render(scene, camera);
    Future.delayed(const Duration(milliseconds: 16), _animate);
  }

  @override
  void dispose() {
    controls?.dispose();
    renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("3D поле")),
      body: SizedBox.expand(
        child: HtmlElementView(viewType: renderer.domElement.id),
      ),
    );
  }
}

// без импортов math, чтобы не тащить лишнее
double mathSin(double v) => (v).sin();
double mathCos(double v) => (v).cos();

extension _Trig on double {
  double sin() => MathShim.sin(this);
  double cos() => MathShim.cos(this);
}

class MathShim {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
  static double _sin(double x) => (x).toDouble(); // заглушка
  static double _cos(double x) => (x).toDouble(); // заглушка
}
