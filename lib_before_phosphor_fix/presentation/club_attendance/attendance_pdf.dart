// lib/presentation/club_attendance/attendance_pdf.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'attendance_models.dart';

class AttendancePdf {
  static Future<void> printMonthTable({
    required String clubName,
    required String teamName,
    required int year,
    required int month,
    required List<AttendancePlayer> players,
    required List<AttendanceEvent> events,
    required Map<String, String> marks, // "playerId|eventId" -> mark
  }) async {
    final doc = pw.Document();

    final title = "$clubName • $teamName";
    final sub = "Журнал посещаемости • $month.$year";

    // Заголовки: ФИО + даты/события (сделаем коротко: день месяца)
    final headers = <String>["ФИО"];
    for (final ev in events) {
      headers.add(ev.date.day.toString());
    }

    // Строки игроков
    final rows = <List<String>>[];
    for (final p in players) {
      final row = <String>[p.fullName];
      for (final ev in events) {
        final key = "${p.id}|${ev.id}";
        row.add(marks[key] ?? "");
      }
      rows.add(row);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(sub, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FlexColumnWidth(3.5),
              for (int i = 1; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
