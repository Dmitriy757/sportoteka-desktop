
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tracker_pro_models.dart';
import 'tracker_training_report_models.dart';

class TrackerTrainingReportApi {
  TrackerTrainingReportApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<TrackerTrainingReport> loadTrainingReport({
    required int sessionId,
    required int teamId,
    required TrackerSessionModel fallbackSession,
    required List<TrackerPlayerOption> rosterPlayers,
  }) async {
    final url = '$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Неверный JSON отчёта');

      final map = Map<String, dynamic>.from(decoded);
      if (map['success'] == false) throw Exception('${map['message'] ?? 'API отчёта вернул ошибку'}');

      return TrackerTrainingReport.fromJson(
        Map<String, dynamic>.from(map['report'] as Map? ?? map),
        fallbackSession: fallbackSession,
      );
    } catch (e) {
      debugPrint('[TrackerTrainingReportApi] fallback report: $e');
      return TrackerTrainingReport.fallback(
        session: fallbackSession,
        rosterPlayers: rosterPlayers,
      );
    }
  }

  String pdfUrl({required int sessionId}) {
    return '$apiBaseUrl/export_training_report_pdf.php?session_id=$sessionId';
  }

  String excelUrl({required int sessionId}) {
    return '$apiBaseUrl/export_training_report_csv.php?session_id=$sessionId';
  }
}
