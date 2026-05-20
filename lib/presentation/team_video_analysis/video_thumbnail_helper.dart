import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailHelper {
  static Future<File?> generateSnapshotFile({
    required String videoPath,
    required int timeMs,
    int quality = 80,
    int maxWidth = 960,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();

      final outputPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: quality,
        maxWidth: maxWidth,
      );

      if (outputPath == null) return null;

      final file = File(outputPath);
      if (!await file.exists()) return null;

      return file;
    } catch (e) {
      return null;
    }
  }
}