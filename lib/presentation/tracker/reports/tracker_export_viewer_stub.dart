import 'package:flutter/material.dart';

class TrackerExportViewer extends StatelessWidget {
  const TrackerExportViewer({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F9),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF374151), size: 22),
            ),
            const SizedBox(height: 12),
            const Text(
              'Встроенный просмотр экспорта',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'На Web PDF/CSV откроется прямо в этом окне. Для macOS/Windows/iOS/Android без PDF-viewer пакета показывается адрес экспорта внутри программы.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 12),
            SelectableText(
              uri.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF374151), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
