import 'dart:convert';
import 'package:http/http.dart' as http;

import 'tracker_training_report_models.dart';

class TrackerTrainingReportApi {
  TrackerTrainingReportApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<TrackerTrainingReport> loadTrainingReport({
    required int sessionId,
    required int teamId,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId');
    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ошибка API (${response.statusCode}): $body');
    }
    final json = jsonDecode(body);
    if (json is! Map) throw Exception('Некорректный JSON отчёта');
    if (json['success'] == false) throw Exception('${json['message'] ?? 'API вернул ошибку'}');
    return TrackerTrainingReport.fromJson(Map<String, dynamic>.from(json['report'] as Map? ?? json));
  }

  Uri pdfExportUri({required int sessionId, required int teamId}) {
    return Uri.parse('$apiBaseUrl/export_training_report_pdf.php?session_id=$sessionId&team_id=$teamId');
  }

  Uri csvExportUri({required int sessionId, required int teamId}) {
    return Uri.parse('$apiBaseUrl/export_training_report_csv.php?session_id=$sessionId&team_id=$teamId');
  }
}
