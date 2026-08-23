import 'dart:math' as math;
import 'package:flutter/material.dart';

class AiTacticalDocumentPreview extends StatelessWidget {
  final String title;
  final Map<String, dynamic> document;
  final VoidCallback? onOpenEditor;
  final VoidCallback? onOpenPdf;
  final VoidCallback? onAddToPlan;

  const AiTacticalDocumentPreview({
    super.key,
    required this.title,
    required this.document,
    this.onOpenEditor,
    this.onOpenPdf,
    this.onAddToPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: CustomPaint(
              painter: _TacticalDocumentPainter(document),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onOpenEditor,
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: const Text('Открыть редактор'),
                    ),
                    if (onAddToPlan != null)
                      OutlinedButton.icon(
                        onPressed: onAddToPlan,
                        icon: const Icon(Icons.playlist_add_rounded, size: 17),
                        label: const Text('В план'),
                      ),
                    if (onOpenPdf != null)
                      OutlinedButton.icon(
                        onPressed: onOpenPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                        label: const Text('PDF'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalDocumentPainter extends CustomPainter {
  final Map<String, dynamic> document;

  _TacticalDocumentPainter(this.document);

  @override
  void paint(Canvas canvas, Size size) {
    final fieldRect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF16854A));

    final white = Paint()
      ..color = Colors.white.withOpacity(.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRect(fieldRect, white);
    canvas.drawLine(
      Offset(fieldRect.center.dx, fieldRect.top),
      Offset(fieldRect.center.dx, fieldRect.bottom),
      white,
    );
    canvas.drawCircle(
      fieldRect.center,
      math.min(fieldRect.width, fieldRect.height) * .12,
      white,
    );

    final logicalWidth =
        (document['field_logical_width'] as num?)?.toDouble() ?? 900;
    final logicalHeight =
        (document['field_logical_height'] as num?)?.toDouble() ?? 1400;

    Offset point(dynamic raw) {
      if (raw is! Map) return Offset.zero;
      final x = (raw['dx'] as num?)?.toDouble() ?? 0;
      final y = (raw['dy'] as num?)?.toDouble() ?? 0;
      return Offset(
        fieldRect.left + (x / logicalWidth) * fieldRect.width,
        fieldRect.top + (y / logicalHeight) * fieldRect.height,
      );
    }

    final elements = document['elements'];
    if (elements is! List) return;

    for (final raw in elements) {
      if (raw is! Map) continue;
      final element = Map<String, dynamic>.from(raw);
      final type = '${element['type'] ?? ''}';

      if (type == 'line') {
        final a = point(element['a']);
        final b = point(element['b']);
        final paint = Paint()
          ..color = Color((element['color'] as num?)?.toInt() ?? 0xFFFFFFFF)
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(a, b, paint);
      }

      if (type == 'stamp') {
        final center = point(element['pos']);
        final asset = '${element['asset'] ?? ''}'.toLowerCase();
        final color = asset.contains('red')
            ? const Color(0xFFEF4444)
            : asset.contains('yellow')
                ? const Color(0xFFFACC15)
                : const Color(0xFF2563EB);
        canvas.drawCircle(center, 6, Paint()..color = color);
        canvas.drawCircle(
          center,
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalDocumentPainter oldDelegate) {
    return oldDelegate.document != document;
  }
}
