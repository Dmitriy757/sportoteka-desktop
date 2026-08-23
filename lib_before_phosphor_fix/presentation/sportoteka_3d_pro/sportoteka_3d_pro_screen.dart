import 'package:flutter/material.dart';

import 'sportoteka_3d_pro_scene.dart';

/// Safe Flutter screen that compiles without a Unity plugin.
///
/// Use it first to verify routing and scene JSON. After Unity export is ready,
/// replace this screen with sportoteka_3d_pro_unity_screen.dart or import that
/// screen from the launcher.
class Sportoteka3DProScreen extends StatefulWidget {
  const Sportoteka3DProScreen({super.key, required this.scene});

  final Sportoteka3DProScene scene;

  @override
  State<Sportoteka3DProScreen> createState() => _Sportoteka3DProScreenState();
}

class _Sportoteka3DProScreenState extends State<Sportoteka3DProScreen> {
  late String _cameraPreset;

  @override
  void initState() {
    super.initState();
    _cameraPreset = widget.scene.camera.preset;
  }

  @override
  Widget build(BuildContext context) {
    final json = widget.scene.toRawJson();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: widget.scene.title),
            Expanded(
              child: Row(
                children: [
                  _SidePanel(
                    scene: widget.scene,
                    cameraPreset: _cameraPreset,
                    onCameraChanged: (value) => setState(() => _cameraPreset = value),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 26,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF101827), Color(0xFF163326)],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.threed_rotation_rounded, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Unity renderer не подключён', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                          SizedBox(height: 3),
                                          Text('Сцена готова. Подключи Unity export, и здесь будет настоящее 3D-поле.', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _PreviewField(scene: widget.scene),
                              ),
                              Container(
                                height: 180,
                                padding: const EdgeInsets.all(14),
                                color: const Color(0xFFF8FAFC),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    json,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Закрыть',
          ),
          const SizedBox(width: 10),
          const Text('Sportoteka 3D Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF101827))),
          const SizedBox(width: 12),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B)))),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Отправить в Unity'),
          ),
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.scene, required this.cameraPreset, required this.onCameraChanged});
  final Sportoteka3DProScene scene;
  final String cameraPreset;
  final ValueChanged<String> onCameraChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ListView(
        children: [
          const Text('Профессиональная сцена', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _InfoTile(label: 'Фаза', value: scene.meta.phase),
          _InfoTile(label: 'Минуты', value: scene.meta.minute),
          _InfoTile(label: 'Объектов', value: '${scene.objects.length}'),
          const SizedBox(height: 18),
          const Text('Камера', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: cameraPreset,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'fifa', child: Text('FIFA / диагональ')),
              DropdownMenuItem(value: 'tv', child: Text('TV трансляция')),
              DropdownMenuItem(value: 'tactical', child: Text('Тактическая')),
              DropdownMenuItem(value: 'top', child: Text('Сверху')),
              DropdownMenuItem(value: 'close', child: Text('Крупный план')),
            ],
            onChanged: (value) {
              if (value != null) onCameraChanged(value);
            },
          ),
          const SizedBox(height: 18),
          const Text('Слои', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...scene.layers.map((layer) => _LayerTile(layer: layer)),
          const SizedBox(height: 18),
          const Text('Объекты', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...scene.objects.map((obj) => _ObjectTile(object: obj)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({required this.layer});
  final Sportoteka3DProLayer layer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(layer.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: const Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(child: Text(layer.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (layer.locked) const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({required this.object});
  final Sportoteka3DProObject object;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(_iconForType(object.type), size: 18, color: const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Expanded(child: Text(object.label.isEmpty ? object.id : object.label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(object.type, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'player':
        return Icons.sports_soccer_rounded;
      case 'ball':
        return Icons.circle_rounded;
      case 'arrow':
        return Icons.trending_flat_rounded;
      case 'zone':
        return Icons.grid_view_rounded;
      case 'label':
        return Icons.label_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.scene});
  final Sportoteka3DProScene scene;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Container(
        color: const Color(0xFF14532D),
        child: CustomPaint(
          painter: _FieldPreviewPainter(scene),
          size: Size(w, h),
        ),
      );
    });
  }
}

class _FieldPreviewPainter extends CustomPainter {
  _FieldPreviewPainter(this.scene);
  final Sportoteka3DProScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final grassA = Paint()..color = const Color(0xFF166534);
    final grassB = Paint()..color = const Color(0xFF15803D);
    for (int i = 0; i < 10; i++) {
      canvas.drawRect(Rect.fromLTWH(i * size.width / 10, 0, size.width / 10, size.height), i.isEven ? grassA : grassB);
    }
    final line = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final field = Rect.fromLTWH(40, 30, size.width - 80, size.height - 60);
    canvas.drawRect(field, line);
    canvas.drawLine(Offset(size.width / 2, 30), Offset(size.width / 2, size.height - 30), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 48, line);

    for (final object in scene.objects) {
      final p = _map(object.x, object.z, size);
      if (object.type == 'player') {
        final paint = Paint()..color = Color(int.parse(object.kitColor.replaceFirst('#', '0xff')));
        canvas.drawCircle(p, 12, paint);
        _drawText(canvas, object.number > 0 ? '${object.number}' : object.label, p.translate(-5, -5), 10, Colors.white);
      } else if (object.type == 'ball') {
        canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      } else if (object.type == 'arrow') {
        final to = _map(object.toX, object.toZ, size);
        final paint = Paint()
          ..color = Color(int.parse(object.color.replaceFirst('#', '0xff')))
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p, to, paint);
        canvas.drawCircle(to, 5, paint);
      } else if (object.type == 'zone') {
        canvas.drawOval(Rect.fromCenter(center: p, width: object.width * 5, height: object.length * 5), Paint()..color = const Color(0x5522C55E));
      }
    }
  }

  Offset _map(double x, double z, Size size) {
    final nx = (x + 52.5) / 105;
    final nz = (z + 34) / 68;
    return Offset(40 + nx * (size.width - 80), 30 + nz * (size.height - 60));
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final span = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w900));
    final painter = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FieldPreviewPainter oldDelegate) => oldDelegate.scene != scene;
}
