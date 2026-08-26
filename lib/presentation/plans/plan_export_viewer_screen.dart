import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart' as http;

import 'pdf_preview_screen.dart';
import 'plan_detail_screen.dart'; // для палитры, если нужно

class PlanExportViewerScreen extends StatefulWidget {
  final String title;
  final String format; // pdf | doc
  final String secureUrl;

  const PlanExportViewerScreen({
    super.key,
    required this.title,
    required this.format,
    required this.secureUrl,
  });

  @override
  State<PlanExportViewerScreen> createState() => _PlanExportViewerScreenState();
}

class _PlanExportViewerScreenState extends State<PlanExportViewerScreen> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _downloadBytes();
  }

  Future<Uint8List> _downloadBytes() async {
    final r = await http.get(Uri.parse(widget.secureUrl));

    // если сервер вернул JSON ошибку
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (ct.contains('application/json')) {
      final m = jsonDecode(r.body);
      throw Exception(m["message"] ?? "Server error");
    }

    if (r.statusCode != 200) {
      throw Exception("HTTP ${r.statusCode}");
    }
    return r.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.format.toLowerCase() == "pdf";

    return Scaffold(
      backgroundColor: ClubDashboardPalette.background,
      appBar: AppBar(
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w900, color: ClubDashboardPalette.text, fontSize: AppTypography.sectionTitleSize),
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ClubDashboardPalette.primaryGreen),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 10),
                    Text("${snap.error}", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = _downloadBytes()),
                      style: ElevatedButton.styleFrom(backgroundColor: ClubDashboardPalette.primaryGreen),
                      child: const Text("Повторить", style: TextStyle(fontFamily: AppTypography.fontFamily, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          final bytes = snap.data!;
          if (isPdf) {
            // ✅ PDF inside
            return PdfPreviewScreen(
              fileName: widget.title,
              buildPdf: (_) async => bytes,
            );
          }

          // ✅ DOC (у тебя это HTML bytes) -> render as HTML
          final html = utf8.decode(bytes, allowMalformed: true);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClubDashboardPalette.border),
              ),
              child: HtmlWidget(html),
            ),
          );
        },
      ),
    );
  }
}
