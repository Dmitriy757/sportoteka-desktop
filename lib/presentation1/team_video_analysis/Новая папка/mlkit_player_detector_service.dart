import 'dart:io';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_player_tracking_models.dart';

class MlkitPlayerDetectorService {
  late final ObjectDetector _detector;
  bool _isBusy = false;

  MlkitPlayerDetectorService() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: false,
      multipleObjects: true,
    );

    _detector = ObjectDetector(options: options);
  }

  bool get isBusy => _isBusy;

  Future<List<DetectedPlayerBox>> detectFromFile(File imageFile) async {
    if (_isBusy) return const [];
    _isBusy = true;

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final objects = await _detector.processImage(inputImage);

      return objects
          .where((obj) {
            final rect = obj.boundingBox;
            return rect.width > 18 && rect.height > 30;
          })
          .map((obj) {
            return DetectedPlayerBox(
              rawTrackId: obj.trackingId?.toString() ?? '',
              bbox: obj.boundingBox,
              confidence: 1.0,
            );
          })
          .toList();
    } catch (_) {
      return const [];
    } finally {
      _isBusy = false;
    }
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}