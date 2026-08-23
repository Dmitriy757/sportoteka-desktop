import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_lessons_usage.dart';

class VideoLessonsSubscriptionService {
  static const String _base = 'https://sportotekaapp.ru/api';
  static const String _usageUrl = '$_base/get_video_lessons_usage.php';

  static Map<String, dynamic> _decode(http.Response resp) {
    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
    try {
      final jsonData = json.decode(body);
      if (jsonData is Map<String, dynamic>) return jsonData;
      return {"success": false};
    } catch (_) {
      return {"success": false};
    }
  }

  static Future<VideoLessonsUsage?> getUsage({
    required int userId,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(_usageUrl),
        body: {
          'user_id': userId.toString(),
        },
      );

      final data = _decode(resp);

      if (data['success'] == true) {
        return VideoLessonsUsage.fromJson(data);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}