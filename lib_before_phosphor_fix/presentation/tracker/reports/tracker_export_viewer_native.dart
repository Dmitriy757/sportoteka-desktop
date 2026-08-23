import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackerExportViewer extends StatelessWidget {
  const TrackerExportViewer({super.key, required this.uri});

  final Uri uri;

  Future<void> _openExternal(BuildContext context) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть отчёт. Проверьте соединение.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = uri.toString().toLowerCase();
    final isPrintableSportotekaReport = url.contains('export_training_report_pdf');
    final isCsv = url.contains('export_training_report_csv') || url.endsWith('.csv') || url.contains('format=csv');
    final isPdf = !isPrintableSportotekaReport && (url.endsWith('.pdf') || url.contains('format=pdf') || url.contains('template=clean'));

    if (isPrintableSportotekaReport || isCsv) {
      final isTable = isCsv;
      return Container(
        color: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.all(18),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: const Color(0xFF00A750), borderRadius: BorderRadius.circular(18)),
                child: Icon(isTable ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(isTable ? 'Excel / CSV отчёт' : 'PDF отчёт', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                isTable
                    ? 'Файл будет открыт или скачан. Выбранные игроки и разделы уже применены.'
                    : 'Откройте отчёт и сохраните его как PDF. Выбранные игроки и разделы уже применены.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 11.6, height: 1.32, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _openExternal(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(isTable ? 'Открыть / скачать CSV' : 'Открыть / сохранить PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A750), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 10),
              const Text('Адрес выгрузки скрыт', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF98A2B3), fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    if (!isPdf) {
      return Container(
        color: const Color(0xFFF7F8FA),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.open_in_new_rounded, color: Color(0xFF00A750), size: 38),
              const SizedBox(height: 12),
              const Text('Открыть выгрузку', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _openExternal(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Открыть'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A750), foregroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text('Адрес выгрузки скрыт', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF98A2B3), fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SfPdfViewer.network(
        uri.toString(),
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: false,
      ),
    );
  }
}
