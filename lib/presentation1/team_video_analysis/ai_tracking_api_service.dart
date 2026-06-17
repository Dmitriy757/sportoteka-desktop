import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'tracking_models.dart';

class AiTrackingApiService {
  static const String baseUrl = 'http://79.98.51.52:5001';

  static Future<List<DetectedPlayerBox>> detectPlayersFromFrameBytes({
    required Uint8List frameBytes,
    required int timeMs,
  }) async {
    final uri = Uri.parse('$baseUrl/analyze_frame');

    final request = http.MultipartRequest('POST', uri)
      ..fields['timeMs'] = timeMs.toString()
      ..files.add(
        http.MultipartFile.fromBytes(
          'frame',
          frameBytes,
          filename: 'frame_$timeMs.jpg',
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'AI server error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Unknown AI error');
    }

    final rawDetections = (data['detections'] as List?) ?? const [];

    return rawDetections
        .whereType<Map>()
        .map((e) => DetectedPlayerBox.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}