import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

class FrameCaptureHelper {
  static Future<Uint8List?> captureFrame({
    required String videoPath,
    required int timeMs,
    int quality = 70,
  }) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: quality,
      );
    } catch (_) {
      return null;
    }
  }
}