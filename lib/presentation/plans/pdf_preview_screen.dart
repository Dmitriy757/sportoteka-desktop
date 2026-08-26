import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String fileName;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  const PdfPreviewScreen({
    super.key,
    required this.fileName,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w800, fontSize: AppTypography.subsectionTitleSize)),
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: fileName,
        build: (format) => buildPdf(format),
      ),
    );
  }
}
